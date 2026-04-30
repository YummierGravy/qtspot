use std::{
    env,
    path::{Path, PathBuf},
};

use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    prefer_qt6_qmake();
    CxxQtBuilder::new_qml_module(QmlModule::new("com.spotix.qt").qml_file("qml/main.qml"))
        .qt_module("Network")
        .qt_module("Quick")
        .qt_module("QuickControls2")
        .files(["src/qt/app_controller.rs"])
        .build();

    #[cfg(windows)]
    add_windows_icon();
}

fn prefer_qt6_qmake() {
    if env::var_os("QMAKE").is_some() {
        return;
    }

    if let Some(qmake6) = find_in_path("qmake6") {
        unsafe {
            env::set_var("QMAKE", qmake6);
        }
    }
}

fn find_in_path(executable: &str) -> Option<PathBuf> {
    let paths = env::var_os("PATH")?;
    env::split_paths(&paths)
        .map(|path| path.join(executable))
        .find(|candidate| is_executable(candidate))
}

fn is_executable(path: &Path) -> bool {
    path.is_file()
}

#[cfg(windows)]
fn add_windows_icon() {
    use image::{
        ColorType,
        codecs::ico::{IcoEncoder, IcoFrame},
    };

    let ico_path = "assets/logo.ico";
    if std::fs::metadata(ico_path).is_err() {
        let ico_frames = load_images();
        save_ico(&ico_frames, ico_path);
    }

    let mut res = winres::WindowsResource::new();
    res.set_icon(ico_path);
    res.compile().expect("Could not attach exe icon");

    fn load_images() -> Vec<IcoFrame<'static>> {
        let sizes = [32, 64, 128, 256];
        sizes
            .iter()
            .map(|s| {
                IcoFrame::as_png(
                    image::open(format!("assets/logo_{s}.png"))
                        .unwrap()
                        .as_bytes(),
                    *s,
                    *s,
                    ColorType::Rgba8.into(),
                )
                .unwrap()
            })
            .collect()
    }

    fn save_ico(images: &[IcoFrame<'_>], ico_path: &str) {
        let file = std::fs::File::create(ico_path).unwrap();
        let encoder = IcoEncoder::new(file);
        encoder.encode_images(images).unwrap();
    }
}
