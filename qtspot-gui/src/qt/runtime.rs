use std::sync::{Mutex, OnceLock};

use spotix_core::session::SessionService;

use crate::data::Config;

#[derive(Clone)]
pub struct QtRuntime {
    pub config: Config,
    pub session: SessionService,
}

static RUNTIME: OnceLock<Mutex<Option<QtRuntime>>> = OnceLock::new();

pub fn init(config: Config, session: SessionService) {
    let runtime = RUNTIME.get_or_init(|| Mutex::new(None));
    *runtime.lock().expect("qt runtime lock poisoned") = Some(QtRuntime { config, session });
}

pub fn snapshot() -> Option<QtRuntime> {
    RUNTIME
        .get_or_init(|| Mutex::new(None))
        .lock()
        .expect("qt runtime lock poisoned")
        .clone()
}

pub fn with_runtime<T>(f: impl FnOnce(&mut QtRuntime) -> T) -> Option<T> {
    let runtime = RUNTIME.get_or_init(|| Mutex::new(None));
    let mut guard = runtime.lock().expect("qt runtime lock poisoned");
    guard.as_mut().map(f)
}

pub fn configure_session_from_config() -> bool {
    with_runtime(|runtime| {
        if runtime.config.has_credentials() {
            runtime.session.update_config(runtime.config.session());
            true
        } else {
            false
        }
    })
    .unwrap_or(false)
}

pub fn store_config(config: Config) {
    let _ = with_runtime(|runtime| {
        runtime.config = config;
    });
}
