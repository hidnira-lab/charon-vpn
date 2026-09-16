use std::io::{BufRead, BufReader};
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::Sender;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use crate::{AppEvent, Waker};

const HEALTH_POLL_INTERVAL: Duration = Duration::from_millis(500);

pub struct XrayProcess {
    child: Arc<Mutex<Child>>,
    stopping: Arc<AtomicBool>,
}

impl XrayProcess {
    pub fn spawn(
        xray_path: &Path,
        config_path: &Path,
        tx: Sender<AppEvent>,
        waker: Waker,
    ) -> std::io::Result<Self> {
        let mut child = Command::new(xray_path)
            .arg("run")
            .arg("-c")
            .arg(config_path)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        if let Some(stdout) = child.stdout.take() {
            spawn_reader(stdout, tx.clone(), waker.clone());
        }
        if let Some(stderr) = child.stderr.take() {
            spawn_reader(stderr, tx.clone(), waker.clone());
        }

        let child = Arc::new(Mutex::new(child));
        let stopping = Arc::new(AtomicBool::new(false));
        spawn_health_watcher(Arc::clone(&child), Arc::clone(&stopping), tx, waker);

        Ok(Self { child, stopping })
    }

    /// Deliberate stop. Sets `stopping` before killing so the health watcher
    /// (which polls concurrently) swallows the resulting exit instead of
    /// reporting it as `AppEvent::XrayStopped` - that event is reserved for
    /// crashes the caller didn't ask for, which is what the supervisor's
    /// kill-switch/auto-reconnect logic reacts to.
    pub fn kill(&mut self) {
        self.stopping.store(true, Ordering::SeqCst);
        let mut child = self.child.lock().unwrap();
        let _ = child.kill();
        let _ = child.wait();
    }
}

fn spawn_reader<R: std::io::Read + Send + 'static>(reader: R, tx: Sender<AppEvent>, waker: Waker) {
    std::thread::spawn(move || {
        let reader = BufReader::new(reader);
        for line in reader.lines() {
            match line {
                Ok(line) => {
                    if tx.send(AppEvent::XrayLog(line)).is_err() {
                        break;
                    }
                    waker();
                }
                Err(_) => break,
            }
        }
    });
}

/// Polls `try_wait` rather than blocking on `Child::wait` so a concurrent
/// `kill()` never deadlocks on a mutex this thread is holding inside a
/// blocking wait.
fn spawn_health_watcher(
    child: Arc<Mutex<Child>>,
    stopping: Arc<AtomicBool>,
    tx: Sender<AppEvent>,
    waker: Waker,
) {
    std::thread::spawn(move || loop {
        std::thread::sleep(HEALTH_POLL_INTERVAL);
        if stopping.load(Ordering::SeqCst) {
            return;
        }
        match child.lock().unwrap().try_wait() {
            Ok(Some(status)) => {
                if !stopping.load(Ordering::SeqCst) {
                    let _ = tx.send(AppEvent::XrayStopped(status.code()));
                    waker();
                }
                return;
            }
            Ok(None) => continue,
            Err(_) => return,
        }
    });
}
