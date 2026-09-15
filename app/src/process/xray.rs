use std::io::{BufRead, BufReader};
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::mpsc::Sender;

use crate::events::AppEvent;

pub struct XrayProcess {
    child: Child,
}

impl XrayProcess {
    pub fn spawn(
        xray_path: &Path,
        config_path: &Path,
        tx: Sender<AppEvent>,
        ctx: egui::Context,
    ) -> std::io::Result<Self> {
        let mut child = Command::new(xray_path)
            .arg("run")
            .arg("-c")
            .arg(config_path)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        if let Some(stdout) = child.stdout.take() {
            spawn_reader(stdout, tx.clone(), ctx.clone());
        }
        if let Some(stderr) = child.stderr.take() {
            spawn_reader(stderr, tx, ctx);
        }

        Ok(Self { child })
    }

    pub fn kill(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

fn spawn_reader<R: std::io::Read + Send + 'static>(
    reader: R,
    tx: Sender<AppEvent>,
    ctx: egui::Context,
) {
    std::thread::spawn(move || {
        let reader = BufReader::new(reader);
        for line in reader.lines() {
            match line {
                Ok(line) => {
                    if tx.send(AppEvent::XrayLog(line)).is_err() {
                        break;
                    }
                    ctx.request_repaint();
                }
                Err(_) => break,
            }
        }
    });
}
