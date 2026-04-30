use std::pin::Pin;

use cxx_qt::casting::Upcast;
use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QQmlEngine, QUrl};
use spotix_core::session::SessionService;

use crate::{
    bootstrap,
    qt::{app_controller, playback_service, runtime},
};

pub fn run() {
    bootstrap::init_logging();
    let config = bootstrap::load_config();
    let session = SessionService::empty();

    runtime::init(config.clone(), session.clone());
    let session_configured = runtime::configure_session_from_config();
    bootstrap::install_webapi(session.clone(), &config);
    playback_service::init(session, &config);
    if config.has_credentials() {
        bootstrap::load_local_tracks(&config);
    }
    app_controller::set_startup_state(config.has_credentials(), session_configured);

    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();

    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/com/spotix/qt/qml/main.qml"));
    }

    if let Some(engine) = engine.as_mut() {
        let engine: Pin<&mut QQmlEngine> = engine.upcast_pin();
        engine
            .on_quit(|_| log::info!("qt: qml quit requested"))
            .release();
    }

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
