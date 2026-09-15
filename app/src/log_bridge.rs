use std::sync::mpsc::Sender;
use std::sync::Mutex;

use log::{Level, LevelFilter, Log, Metadata, Record};

use crate::events::AppEvent;

struct ChannelLogger {
    tx: Mutex<Sender<AppEvent>>,
    ctx: egui::Context,
}

impl Log for ChannelLogger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        metadata.level() <= Level::Warn
    }

    fn log(&self, record: &Record) {
        if !self.enabled(record.metadata()) {
            return;
        }
        let line = format!("[tunnel] {} {}", record.level(), record.args());
        if let Ok(tx) = self.tx.lock() {
            let _ = tx.send(AppEvent::TunnelLog(line));
        }
        self.ctx.request_repaint();
    }

    fn flush(&self) {}
}

/// Registers the process-global logger. Must only be called once per process.
pub fn init(tx: Sender<AppEvent>, ctx: egui::Context) {
    let logger = ChannelLogger {
        tx: Mutex::new(tx),
        ctx,
    };
    if log::set_boxed_logger(Box::new(logger)).is_ok() {
        log::set_max_level(LevelFilter::Warn);
    }
}
