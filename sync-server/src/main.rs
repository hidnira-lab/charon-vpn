use std::collections::HashMap;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

use serde_json::{json, Value};

/// Max frame size accepted from a client - guards against a malformed or
/// hostile length prefix asking us to allocate an unreasonable buffer.
/// The largest real payload (a synced config blob) is expected to be a few
/// KB, so this leaves generous headroom without being unbounded.
const MAX_FRAME_BYTES: u32 = 10 * 1024 * 1024;

/// Flat-file storage for the device registry and the single synced config
/// blob. Single-tenant by design (see plan doc) - this server only ever
/// serves one user's own devices, so there's no per-pairing-group
/// partitioning to build. Tokens are stored in plaintext, not hashed:
/// anyone who can read this file already has root on the VPS, at which
/// point a hash buys nothing (they can read the source, patch the binary,
/// etc.) - see the sync-server section of the Milestone 11 plan.
struct Store {
    dir: PathBuf,
}

impl Store {
    fn new(dir: PathBuf) -> std::io::Result<Self> {
        std::fs::create_dir_all(&dir)?;
        Ok(Self { dir })
    }

    fn devices_path(&self) -> PathBuf {
        self.dir.join("devices.json")
    }

    fn blob_path(&self) -> PathBuf {
        self.dir.join("blob.json")
    }

    fn load_devices(&self) -> HashMap<String, Value> {
        std::fs::read_to_string(self.devices_path())
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default()
    }

    fn save_devices(&self, devices: &HashMap<String, Value>) -> std::io::Result<()> {
        std::fs::write(self.devices_path(), serde_json::to_string_pretty(devices).unwrap())
    }

    fn register(&self, device_name: &str) -> String {
        let token = generate_token();
        let mut devices = self.load_devices();
        devices.insert(
            token.clone(),
            json!({ "name": device_name, "registeredAt": epoch_seconds() }),
        );
        self.save_devices(&devices).expect("failed to write devices.json");
        token
    }

    fn device_name(&self, token: &str) -> Option<String> {
        self.load_devices()
            .get(token)
            .and_then(|d| d.get("name"))
            .and_then(|n| n.as_str())
            .map(str::to_owned)
    }

    fn is_valid_token(&self, token: &str) -> bool {
        self.load_devices().contains_key(token)
    }

    fn load_blob(&self) -> Option<Value> {
        std::fs::read_to_string(self.blob_path()).ok().and_then(|s| serde_json::from_str(&s).ok())
    }

    fn save_blob(&self, blob: &Value) -> std::io::Result<()> {
        std::fs::write(self.blob_path(), serde_json::to_string_pretty(blob).unwrap())
    }
}

fn generate_token() -> String {
    let mut bytes = [0u8; 32];
    getrandom::getrandom(&mut bytes).expect("failed to read OS randomness");
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn epoch_seconds() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
}

fn error_response(msg: &str) -> Vec<u8> {
    serde_json::to_vec(&json!({ "ok": false, "error": msg })).unwrap()
}

/// The server never inspects `ciphertext`/`salt`/`nonce` beyond passing them
/// through as opaque strings - encryption is end-to-end on the client side
/// (see `sync_crypto.dart`), this process never sees plaintext or the
/// passphrase that derives the key.
fn handle_request(frame: &[u8], store: &Mutex<Store>) -> Vec<u8> {
    let request: Value = match serde_json::from_slice(frame) {
        Ok(v) => v,
        Err(e) => return error_response(&format!("invalid JSON: {e}")),
    };
    let op = request.get("op").and_then(Value::as_str).unwrap_or("");
    let store = store.lock().unwrap();

    match op {
        "register" => {
            let device_name = request.get("deviceName").and_then(Value::as_str).unwrap_or("unnamed device");
            let token = store.register(device_name);
            serde_json::to_vec(&json!({ "ok": true, "token": token })).unwrap()
        }
        "push" => {
            let token = request.get("token").and_then(Value::as_str).unwrap_or("");
            if !store.is_valid_token(token) {
                return error_response("invalid token");
            }
            let updated_by = store.device_name(token).unwrap_or_else(|| "unknown".to_string());
            let blob = json!({
                "ciphertext": request.get("ciphertext"),
                "salt": request.get("salt"),
                "nonce": request.get("nonce"),
                "updatedAt": request.get("updatedAt"),
                "updatedBy": updated_by,
            });
            store.save_blob(&blob).expect("failed to write blob.json");
            serde_json::to_vec(&json!({ "ok": true })).unwrap()
        }
        "pull" => {
            let token = request.get("token").and_then(Value::as_str).unwrap_or("");
            if !store.is_valid_token(token) {
                return error_response("invalid token");
            }
            match store.load_blob() {
                Some(mut blob) => {
                    blob["ok"] = json!(true);
                    blob["found"] = json!(true);
                    serde_json::to_vec(&blob).unwrap()
                }
                None => serde_json::to_vec(&json!({ "ok": true, "found": false })).unwrap(),
            }
        }
        other => error_response(&format!("unknown op: {other}")),
    }
}

fn read_frame(stream: &mut TcpStream) -> std::io::Result<Vec<u8>> {
    let mut len_buf = [0u8; 4];
    stream.read_exact(&mut len_buf)?;
    let len = u32::from_be_bytes(len_buf);
    if len > MAX_FRAME_BYTES {
        return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "frame too large"));
    }
    let mut buf = vec![0u8; len as usize];
    stream.read_exact(&mut buf)?;
    Ok(buf)
}

fn write_frame(stream: &mut TcpStream, data: &[u8]) -> std::io::Result<()> {
    stream.write_all(&(data.len() as u32).to_be_bytes())?;
    stream.write_all(data)
}

/// One request, one response, then close - matches the client, which opens
/// a fresh SOCKS5-tunneled connection per operation rather than keeping one
/// alive across push/pull calls (see `sync_client.dart`).
fn handle_connection(mut stream: TcpStream, store: &Mutex<Store>) {
    let frame = match read_frame(&mut stream) {
        Ok(f) => f,
        Err(_) => return,
    };
    let response = handle_request(&frame, store);
    let _ = write_frame(&mut stream, &response);
}

fn main() {
    let mut args = std::env::args().skip(1);
    let data_dir = args.next().map(PathBuf::from).unwrap_or_else(|| PathBuf::from("./charon-sync-data"));
    let port: u16 = args.next().and_then(|s| s.parse().ok()).unwrap_or(8787);

    let store = Arc::new(Mutex::new(Store::new(data_dir).expect("failed to create storage dir")));
    let listener = TcpListener::bind(("127.0.0.1", port)).expect("failed to bind");
    println!("charon-sync listening on 127.0.0.1:{port}");

    for conn in listener.incoming() {
        match conn {
            Ok(stream) => {
                let store = Arc::clone(&store);
                std::thread::spawn(move || handle_connection(stream, &store));
            }
            Err(e) => eprintln!("accept error: {e}"),
        }
    }
}
