pub mod events;
pub mod log_bridge;
pub mod platform;
pub mod tunnel;
pub mod xray;

pub use events::AppEvent;

use std::sync::Arc;

/// UI-agnostic callback used to wake up a UI's redraw loop when a background
/// thread pushes an event asynchronously (e.g. egui's `ctx.request_repaint()`).
/// Platforms without a pull-driven redraw loop (e.g. Flutter, which reacts to
/// stream events on its own) can pass a no-op.
pub type Waker = Arc<dyn Fn() + Send + Sync>;
