use std::{
    collections::HashMap,
    sync::{Arc, Mutex, OnceLock},
    thread::{self, JoinHandle},
    time::Duration,
};

use crossbeam_channel::Sender;
use spotix_core::{
    audio::{normalize::NormalizationLevel, output::DefaultAudioOutput},
    cache::Cache,
    cdn::Cdn,
    item_id::{ItemId, ItemIdType},
    player::{Player, PlayerCommand, PlayerEvent, item::PlaybackItem, queue::QueueBehavior},
    session::SessionService,
};

use crate::{
    data::{Config, SearchTopic, Track},
    webapi::WebApi,
};

#[derive(Clone)]
pub struct PlaybackSnapshot {
    pub state: PlaybackUiState,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub track_id: String,
    pub image_url: String,
    pub progress: Duration,
    pub duration: Duration,
    pub volume: f64,
    pub spectrum_bands: [f32; 16],
    pub shuffle: bool,
    pub queue_summary: String,
    pub status: String,
}

impl Default for PlaybackSnapshot {
    fn default() -> Self {
        Self {
            state: PlaybackUiState::Stopped,
            title: "Nothing playing".to_string(),
            artist: "Select a track to start playback".to_string(),
            album: String::new(),
            track_id: String::new(),
            image_url: String::new(),
            progress: Duration::ZERO,
            duration: Duration::ZERO,
            volume: 1.0,
            spectrum_bands: [0.0; 16],
            shuffle: false,
            queue_summary: "Queue is empty".to_string(),
            status: "Playback service is idle".to_string(),
        }
    }
}

#[derive(Clone, Copy)]
pub enum PlaybackUiState {
    Loading,
    Playing,
    Paused,
    Blocked,
    Stopped,
}

impl PlaybackUiState {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Loading => "Loading",
            Self::Playing => "Playing",
            Self::Paused => "Paused",
            Self::Blocked => "Blocked",
            Self::Stopped => "Stopped",
        }
    }
}

#[derive(Clone)]
struct TrackMetadata {
    title: String,
    artist: String,
    album: String,
    image_url: String,
    duration: Duration,
}

pub struct QtPlaybackService {
    sender: Sender<PlayerEvent>,
    snapshot: Arc<Mutex<PlaybackSnapshot>>,
    meter: spotix_core::audio::meter::PcmMeter,
    metadata: Arc<Mutex<HashMap<ItemId, TrackMetadata>>>,
    _thread: JoinHandle<()>,
    _output: DefaultAudioOutput,
}

static PLAYBACK_SERVICE: OnceLock<Mutex<Option<QtPlaybackService>>> = OnceLock::new();

pub fn init(session: SessionService, config: &Config) {
    let service = match QtPlaybackService::new(session, config) {
        Ok(service) => service,
        Err(err) => {
            log::error!("qt playback: failed to initialize playback service: {err}");
            return;
        }
    };

    let store = PLAYBACK_SERVICE.get_or_init(|| Mutex::new(None));
    *store.lock().expect("qt playback service lock poisoned") = Some(service);
}

pub fn snapshot() -> PlaybackSnapshot {
    with_service(|service| service.snapshot()).unwrap_or_else(|| PlaybackSnapshot {
        status: "Playback service is not initialized".to_string(),
        ..PlaybackSnapshot::default()
    })
}

pub fn play_first_search_result(query: &str) -> Result<String, String> {
    let query = query.trim();
    if query.is_empty() {
        return Err("Enter a search term first".to_string());
    }
    if WebApi::global().is_rate_limited() {
        return Err("Spotify search is rate limited".to_string());
    }

    let results = WebApi::global()
        .search(query, &[SearchTopic::Track], 10)
        .map_err(|err| err.to_string())?;
    let track = results
        .tracks
        .iter()
        .find(|track| !matches!(track.is_playable, Some(false)))
        .cloned()
        .ok_or_else(|| "No playable tracks found".to_string())?;

    with_service(|service| service.play_tracks(vec![track], 0))
        .unwrap_or_else(|| Err("Playback service is not initialized".to_string()))
}

pub fn pause_or_resume() {
    send(PlayerCommand::PauseOrResume);
}

pub fn previous() {
    send(PlayerCommand::Previous);
}

pub fn next() {
    send(PlayerCommand::Next);
}

pub fn stop() {
    send(PlayerCommand::Stop);
}

pub fn toggle_shuffle() -> bool {
    with_service(|service| service.toggle_shuffle()).unwrap_or(false)
}

pub fn seek(progress_ratio: f64) {
    let duration = snapshot().duration;
    if duration.is_zero() {
        return;
    }
    let clamped = progress_ratio.clamp(0.0, 1.0);
    send(PlayerCommand::Seek {
        position: duration.mul_f64(clamped),
    });
}

pub fn set_volume(volume: f64) {
    let volume = volume.clamp(0.0, 1.0);
    let _ = with_service(|service| {
        service.update_snapshot(|snapshot| {
            snapshot.volume = volume;
        });
    });
    send(PlayerCommand::SetVolume {
        volume: ui_volume_to_backend(volume),
    });
}

fn ui_volume_to_backend(volume: f64) -> f64 {
    if volume <= 0.0 {
        0.0
    } else {
        volume.clamp(0.0, 1.0).powf(0.25)
    }
}

pub fn register_tracks(tracks: impl IntoIterator<Item = Arc<Track>>) {
    let _ = with_service(|service| {
        service.register_tracks(tracks);
    });
}

pub fn play_track_id(id: &str) -> Result<String, String> {
    let item_id = ItemId::from_base62(id, ItemIdType::Track)
        .ok_or_else(|| format!("Invalid track id: {id}"))?;
    with_service(|service| service.play_track_id(item_id))
        .unwrap_or_else(|| Err("Playback service is not initialized".to_string()))
}

pub fn play_track_context(id: &str, context_ids: Vec<String>) -> Result<String, String> {
    let item_id = ItemId::from_base62(id, ItemIdType::Track)
        .ok_or_else(|| format!("Invalid track id: {id}"))?;
    let mut item_ids = context_ids
        .iter()
        .filter_map(|id| ItemId::from_base62(id, ItemIdType::Track))
        .collect::<Vec<_>>();
    if item_ids.is_empty() {
        item_ids.push(item_id);
    }
    let position = item_ids
        .iter()
        .position(|candidate| *candidate == item_id)
        .unwrap_or(0);
    with_service(|service| service.play_item_ids(item_ids, position))
        .unwrap_or_else(|| Err("Playback service is not initialized".to_string()))
}

fn send(command: PlayerCommand) {
    let _ = with_service(|service| {
        service.send(command);
    });
}

fn with_service<T>(f: impl FnOnce(&QtPlaybackService) -> T) -> Option<T> {
    let store = PLAYBACK_SERVICE.get_or_init(|| Mutex::new(None));
    let guard = store.lock().expect("qt playback service lock poisoned");
    guard.as_ref().map(f)
}

impl QtPlaybackService {
    fn new(session: SessionService, config: &Config) -> Result<Self, String> {
        let output = DefaultAudioOutput::open().map_err(|err| err.to_string())?;
        let cache_dir =
            Config::cache_dir().ok_or_else(|| "No cache directory found".to_string())?;
        let proxy_url = Config::proxy();
        let player = Player::new(
            session.clone(),
            Cdn::new(session, proxy_url.as_deref()).map_err(|err| err.to_string())?,
            Cache::new(cache_dir).map_err(|err| err.to_string())?,
            config.playback(),
            &output,
            config.credentials_clone(),
        );
        let meter = player.pcm_meter();
        let sender = player.sender();
        let snapshot = Arc::new(Mutex::new(PlaybackSnapshot {
            volume: config.volume,
            status: "Playback service is ready".to_string(),
            ..PlaybackSnapshot::default()
        }));
        let metadata = Arc::new(Mutex::new(HashMap::new()));
        let thread_snapshot = Arc::clone(&snapshot);
        let thread_metadata = Arc::clone(&metadata);

        let thread = thread::spawn(move || {
            Self::service_events(player, thread_snapshot, thread_metadata);
        });

        sender
            .send(PlayerEvent::Command(PlayerCommand::SetVolume {
                volume: ui_volume_to_backend(config.volume),
            }))
            .map_err(|err| err.to_string())?;

        Ok(Self {
            sender,
            snapshot,
            meter,
            metadata,
            _thread: thread,
            _output: output,
        })
    }

    fn snapshot(&self) -> PlaybackSnapshot {
        let mut snapshot = self
            .snapshot
            .lock()
            .expect("qt playback snapshot lock poisoned");
        snapshot.spectrum_bands = if matches!(snapshot.state, PlaybackUiState::Playing) {
            self.meter.levels()
        } else {
            [0.0; 16]
        };
        snapshot.clone()
    }

    fn update_snapshot(&self, f: impl FnOnce(&mut PlaybackSnapshot)) {
        let mut snapshot = self
            .snapshot
            .lock()
            .expect("qt playback snapshot lock poisoned");
        f(&mut snapshot);
    }

    fn send(&self, command: PlayerCommand) {
        if let Err(err) = self.sender.send(PlayerEvent::Command(command)) {
            log::warn!("qt playback: failed to send player command: {err}");
        }
    }

    fn toggle_shuffle(&self) -> bool {
        let shuffle = {
            let mut snapshot = self
                .snapshot
                .lock()
                .expect("qt playback snapshot lock poisoned");
            snapshot.shuffle = !snapshot.shuffle;
            snapshot.status = if snapshot.shuffle {
                "Shuffle enabled".to_string()
            } else {
                "Shuffle disabled".to_string()
            };
            snapshot.shuffle
        };
        self.send(PlayerCommand::SetQueueBehavior {
            behavior: if shuffle {
                QueueBehavior::Random
            } else {
                QueueBehavior::Sequential
            },
        });
        shuffle
    }

    fn play_tracks(&self, tracks: Vec<Arc<Track>>, position: usize) -> Result<String, String> {
        if tracks.is_empty() {
            return Err("No tracks to play".to_string());
        }

        let mut metadata = self
            .metadata
            .lock()
            .expect("qt playback metadata lock poisoned");
        let items = tracks
            .iter()
            .map(|track| {
                metadata.insert(
                    track.id.0,
                    TrackMetadata {
                        title: track.name.to_string(),
                        artist: track.artist_names(),
                        album: track.album_name().to_string(),
                        image_url: track_image_url(track),
                        duration: track.duration,
                    },
                );
                PlaybackItem {
                    item_id: track.id.0,
                    norm_level: NormalizationLevel::Track,
                }
            })
            .collect::<Vec<_>>();
        drop(metadata);

        let position = position.min(items.len().saturating_sub(1));
        self.sender
            .send(PlayerEvent::Command(PlayerCommand::LoadQueue {
                items,
                position,
            }))
            .map_err(|err| err.to_string())?;

        self.update_snapshot(|snapshot| {
            snapshot.queue_summary = format!("{} track(s) queued", tracks.len());
            snapshot.status = "Loading queue".to_string();
        });

        Ok(format!("Playing {}", tracks[position].name))
    }

    fn register_tracks(&self, tracks: impl IntoIterator<Item = Arc<Track>>) {
        let mut metadata = self
            .metadata
            .lock()
            .expect("qt playback metadata lock poisoned");
        for track in tracks {
            metadata.insert(
                track.id.0,
                TrackMetadata {
                    title: track.name.to_string(),
                    artist: track.artist_names(),
                    album: track.album_name().to_string(),
                    image_url: track_image_url(&track),
                    duration: track.duration,
                },
            );
        }
    }

    fn play_track_id(&self, item_id: ItemId) -> Result<String, String> {
        let title = self
            .metadata
            .lock()
            .expect("qt playback metadata lock poisoned")
            .get(&item_id)
            .map(|metadata| metadata.title.clone())
            .unwrap_or_else(|| item_id.to_base62());

        self.sender
            .send(PlayerEvent::Command(PlayerCommand::LoadAndPlay {
                item: PlaybackItem {
                    item_id,
                    norm_level: NormalizationLevel::Track,
                },
            }))
            .map_err(|err| err.to_string())?;

        self.update_snapshot(|snapshot| {
            snapshot.status = "Loading track".to_string();
            snapshot.queue_summary = "Single track playback".to_string();
        });

        Ok(format!("Playing {title}"))
    }

    fn play_item_ids(&self, item_ids: Vec<ItemId>, position: usize) -> Result<String, String> {
        if item_ids.is_empty() {
            return Err("No tracks to play".to_string());
        }

        let items = item_ids
            .iter()
            .map(|item_id| PlaybackItem {
                item_id: *item_id,
                norm_level: NormalizationLevel::Track,
            })
            .collect::<Vec<_>>();
        let position = position.min(items.len().saturating_sub(1));
        let title = self
            .metadata
            .lock()
            .expect("qt playback metadata lock poisoned")
            .get(&item_ids[position])
            .map(|metadata| metadata.title.clone())
            .unwrap_or_else(|| item_ids[position].to_base62());

        self.sender
            .send(PlayerEvent::Command(PlayerCommand::LoadQueue {
                items,
                position,
            }))
            .map_err(|err| err.to_string())?;

        self.update_snapshot(|snapshot| {
            snapshot.status = "Loading queue".to_string();
            snapshot.queue_summary = format!("{} track(s) queued", item_ids.len());
        });

        Ok(format!("Playing {title}"))
    }

    fn service_events(
        mut player: Player,
        snapshot: Arc<Mutex<PlaybackSnapshot>>,
        metadata: Arc<Mutex<HashMap<ItemId, TrackMetadata>>>,
    ) {
        for event in player.receiver() {
            Self::update_from_event(&snapshot, &metadata, &event);
            player.handle(event);
        }
    }

    fn update_from_event(
        snapshot: &Arc<Mutex<PlaybackSnapshot>>,
        metadata: &Arc<Mutex<HashMap<ItemId, TrackMetadata>>>,
        event: &PlayerEvent,
    ) {
        let mut snapshot = snapshot.lock().expect("qt playback snapshot lock poisoned");
        match event {
            PlayerEvent::Loading { item } => {
                snapshot.state = PlaybackUiState::Loading;
                snapshot.status = "Loading track".to_string();
                Self::apply_metadata(&mut snapshot, metadata, item.item_id);
            }
            PlayerEvent::Playing { path, position } => {
                snapshot.state = PlaybackUiState::Playing;
                snapshot.progress = *position;
                snapshot.status = "Playing".to_string();
                Self::apply_metadata(&mut snapshot, metadata, path.item_id);
            }
            PlayerEvent::Pausing { path, position } => {
                snapshot.state = PlaybackUiState::Paused;
                snapshot.progress = *position;
                snapshot.status = "Paused".to_string();
                Self::apply_metadata(&mut snapshot, metadata, path.item_id);
            }
            PlayerEvent::Resuming { path, position } | PlayerEvent::Position { path, position } => {
                snapshot.state = PlaybackUiState::Playing;
                snapshot.progress = *position;
                snapshot.status = "Playing".to_string();
                Self::apply_metadata(&mut snapshot, metadata, path.item_id);
            }
            PlayerEvent::Blocked { path, position } => {
                snapshot.state = PlaybackUiState::Blocked;
                snapshot.progress = *position;
                snapshot.status = "Buffering".to_string();
                Self::apply_metadata(&mut snapshot, metadata, path.item_id);
            }
            PlayerEvent::Stopped => {
                snapshot.state = PlaybackUiState::Stopped;
                snapshot.title = "Nothing playing".to_string();
                snapshot.artist = "Select a track to start playback".to_string();
                snapshot.album.clear();
                snapshot.track_id.clear();
                snapshot.image_url.clear();
                snapshot.progress = Duration::ZERO;
                snapshot.duration = Duration::ZERO;
                snapshot.status = "Stopped".to_string();
            }
            _ => {}
        }
    }

    fn apply_metadata(
        snapshot: &mut PlaybackSnapshot,
        metadata: &Arc<Mutex<HashMap<ItemId, TrackMetadata>>>,
        item_id: ItemId,
    ) {
        snapshot.track_id = item_id.to_base62();
        let metadata = metadata.lock().expect("qt playback metadata lock poisoned");
        if let Some(track) = metadata.get(&item_id) {
            snapshot.title.clone_from(&track.title);
            snapshot.artist.clone_from(&track.artist);
            snapshot.album.clone_from(&track.album);
            snapshot.image_url.clone_from(&track.image_url);
            snapshot.duration = track.duration;
        }
    }
}

fn track_image_url(track: &Track) -> String {
    track
        .album
        .as_ref()
        .and_then(|album| album.images.front())
        .map(|image| image.url.to_string())
        .unwrap_or_default()
}
