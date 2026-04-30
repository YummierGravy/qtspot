use env_logger::{Builder, Env};
use spotix_core::{
    cache::{Cache, CacheHandle},
    session::SessionService,
};

use crate::{data::Config, webapi::WebApi};

pub const ENV_LOG: &str = "QTSPOT_LOG";
pub const ENV_LOG_STYLE: &str = "QTSPOT_LOG_STYLE";

pub fn init_logging() {
    Builder::from_env(
        Env::new()
            .filter_or(ENV_LOG, "info,rspotify_http=warn")
            .write_style(ENV_LOG_STYLE),
    )
    .init();
}

pub fn load_config() -> Config {
    let mut config = Config::load().unwrap_or_default();
    let device_id = config.ensure_device_id();
    unsafe {
        std::env::set_var("QTSPOT_DEVICE_ID", &device_id);
    }
    if config.device_id.as_deref() != Some(&device_id) {
        config.save();
    }
    config
}

pub fn create_cache() -> Option<CacheHandle> {
    let cache_dir = Config::cache_dir()?;
    match Cache::new(cache_dir) {
        Ok(cache) => Some(cache),
        Err(err) => {
            log::error!("Failed to create cache: {err}");
            None
        }
    }
}

pub fn install_webapi(session: SessionService, config: &Config) {
    if config.oauth_token_clone().is_some() {
        log::info!("webapi: oauth token loaded from config");
    } else {
        log::warn!("webapi: no oauth token in config (re-auth needed for webapi)");
    }

    WebApi::new(
        session,
        Config::proxy().as_deref(),
        Config::cache_dir(),
        config.oauth_token_clone(),
        config.paginated_limit,
        config.effective_webapi_client_id().to_string(),
    )
    .install_as_global();
}

pub fn load_local_tracks(config: &Config) {
    if let Some(username) = config.username() {
        WebApi::global().load_local_tracks(username);
    }
}
