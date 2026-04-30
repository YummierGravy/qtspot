mod album;
mod artist;
pub mod config;
mod id;
mod nav;
mod playback;
mod playlist;
mod promise;
mod recommend;
mod search;
mod show;
mod slider_scroll_scale;
mod track;
mod user;
pub mod utils;

use std::sync::Arc;

use im::Vector;
use serde::Deserialize;

pub use crate::data::{
    album::{Album, AlbumDetail, AlbumLink, AlbumType},
    artist::{
        Artist, ArtistAlbums, ArtistDetail, ArtistInfo, ArtistLink, ArtistStats, ArtistTracks,
    },
    config::{
        AudioQuality, Authentication, CacheUsage, Config, EqBands, EqPreset, EqSettings,
        LyricsAppearance, PlaybackEngine, SortCriteria, SortOrder, Theme, WindowSize,
    },
    id::Id,
    nav::{Nav, Route, SpotifyUrl},
    playback::QueueBehavior,
    playlist::{
        Playlist, PlaylistAddTrack, PlaylistDetail, PlaylistLink, PlaylistRemoveTrack,
        PlaylistRemoveTrackItem, PlaylistRemoveTracks, PlaylistTracks,
    },
    promise::{Promise, PromiseState},
    recommend::{
        Range, Recommend, Recommendations, RecommendationsKnobs, RecommendationsParams,
        RecommendationsRequest, Toggled,
    },
    search::{SearchResults, SearchTopic},
    show::{Episode, EpisodeId, EpisodeLink, Show, ShowDetail, ShowEpisodes, ShowLink},
    slider_scroll_scale::SliderScrollScale,
    track::{AudioAnalysis, Track, TrackId, TrackLines},
    user::{PublicUser, UserProfile},
    utils::{Cached, Float64, Image, Page},
};

#[derive(Clone)]
pub struct Library {
    pub user_profile: Promise<UserProfile>,
    pub playlists: Promise<Vector<Playlist>>,
}

#[derive(Clone)]
pub struct MixedView {
    pub title: Arc<str>,
    pub playlists: Vector<Playlist>,
    pub albums: Vector<Arc<Album>>,
    pub artists: Vector<Artist>,
    pub shows: Vector<Arc<Show>>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrackCredits {
    pub track_uri: String,
    pub track_title: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub role_credits: Arc<Vec<RoleCredit>>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub extended_credits: Arc<Vec<String>>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub source_names: Arc<Vec<String>>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RoleCredit {
    #[serde(rename = "roleTitle")]
    pub role_title: String,
    pub artists: Arc<Vec<CreditArtist>>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CreditArtist {
    pub uri: Option<String>,
    pub name: String,
    #[serde(rename = "imageUri")]
    pub image_uri: Option<String>,
    #[serde(rename = "externalUrl")]
    pub external_url: Option<String>,
    #[serde(rename = "creatorUri")]
    pub creator_uri: Option<String>,
    #[serde(default)]
    pub subroles: Arc<Vec<String>>,
    #[serde(default)]
    pub weight: f64,
}
