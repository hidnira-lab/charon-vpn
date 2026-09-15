#[cfg(windows)]
mod windows;
#[cfg(windows)]
pub use windows::TunnelHandle;

#[cfg(target_os = "android")]
mod android;
#[cfg(target_os = "android")]
pub use android::TunnelHandle;
