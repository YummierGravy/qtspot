use crate::data::{Album, Artist, Episode, Playlist, SearchResults, Show, Track};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct QtImage {
    pub url: String,
    pub width: i32,
    pub height: i32,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct QtTrack {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_ms: i32,
    pub image_url: String,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct QtAlbum {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub image_url: String,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct QtArtist {
    pub id: String,
    pub name: String,
    pub image_url: String,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct QtPlaylist {
    pub id: String,
    pub title: String,
    pub owner: String,
    pub image_url: String,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct QtShow {
    pub id: String,
    pub title: String,
    pub publisher: String,
    pub image_url: String,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct QtSearchResults {
    pub query: String,
    pub tracks: Vec<QtTrack>,
    pub albums: Vec<QtAlbum>,
    pub artists: Vec<QtArtist>,
    pub playlists: Vec<QtPlaylist>,
    pub shows: Vec<QtShow>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct QtTreeItem {
    pub id: String,
    pub parent_id: String,
    pub kind: String,
    pub label: String,
    pub meta: String,
    pub image_url: String,
    pub art_ascii: String,
    pub depth: i32,
    pub expanded: bool,
    pub selectable: bool,
    pub playable: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct QtDetailRow {
    pub id: String,
    pub kind: String,
    pub label: String,
    pub meta: String,
    pub image_url: String,
    pub art_ascii: String,
    pub depth: i32,
    pub playable: bool,
    pub expandable: bool,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct QtNavDocument {
    pub title: String,
    pub status: String,
    pub route_art_ascii: String,
    pub rows: Vec<QtDetailRow>,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct QtEpisode {
    pub id: String,
    pub title: String,
    pub show: String,
    pub duration_ms: i32,
}

impl From<&Track> for QtTrack {
    fn from(track: &Track) -> Self {
        Self {
            id: track.id.0.to_base62(),
            title: track.name.to_string(),
            artist: track.artist_names(),
            album: track.album_name().to_string(),
            duration_ms: duration_ms(track.duration),
            image_url: track
                .album
                .as_ref()
                .and_then(|album| album.images.front())
                .map(|image| image.url.to_string())
                .unwrap_or_default(),
        }
    }
}

impl From<&Album> for QtAlbum {
    fn from(album: &Album) -> Self {
        Self {
            id: album.id.to_string(),
            title: album.name.to_string(),
            artist: album
                .artists
                .front()
                .map(|artist| artist.name.to_string())
                .unwrap_or_default(),
            image_url: album
                .images
                .front()
                .map(|image| image.url.to_string())
                .unwrap_or_default(),
        }
    }
}

impl From<&Artist> for QtArtist {
    fn from(artist: &Artist) -> Self {
        Self {
            id: artist.id.to_string(),
            name: artist.name.to_string(),
            image_url: artist
                .images
                .front()
                .map(|image| image.url.to_string())
                .unwrap_or_default(),
        }
    }
}

impl From<&Playlist> for QtPlaylist {
    fn from(playlist: &Playlist) -> Self {
        Self {
            id: playlist.id.to_string(),
            title: playlist.name.to_string(),
            owner: playlist.owner.display_name.to_string(),
            image_url: playlist
                .images
                .as_ref()
                .and_then(|images| images.front())
                .map(|image| image.url.to_string())
                .unwrap_or_default(),
        }
    }
}

impl From<&Show> for QtShow {
    fn from(show: &Show) -> Self {
        Self {
            id: show.id.to_string(),
            title: show.name.to_string(),
            publisher: show.publisher.to_string(),
            image_url: show
                .images
                .front()
                .map(|image| image.url.to_string())
                .unwrap_or_default(),
        }
    }
}

impl From<&SearchResults> for QtSearchResults {
    fn from(results: &SearchResults) -> Self {
        Self {
            query: results.query.to_string(),
            tracks: results
                .tracks
                .iter()
                .map(|track| QtTrack::from(&**track))
                .collect(),
            albums: results
                .albums
                .iter()
                .map(|album| QtAlbum::from(&**album))
                .collect(),
            artists: results.artists.iter().map(QtArtist::from).collect(),
            playlists: results.playlists.iter().map(QtPlaylist::from).collect(),
            shows: results
                .shows
                .iter()
                .map(|show| QtShow::from(&**show))
                .collect(),
        }
    }
}

impl From<&Episode> for QtEpisode {
    fn from(episode: &Episode) -> Self {
        Self {
            id: episode.id.0.to_base62(),
            title: episode.name.to_string(),
            show: episode.show.name.to_string(),
            duration_ms: duration_ms(episode.duration),
        }
    }
}

impl QtDetailRow {
    pub fn route(
        id: impl Into<String>,
        kind: impl Into<String>,
        label: impl Into<String>,
        meta: impl Into<String>,
        depth: i32,
    ) -> Self {
        Self {
            id: id.into(),
            kind: kind.into(),
            label: label.into(),
            meta: meta.into(),
            image_url: String::new(),
            art_ascii: String::new(),
            depth,
            playable: false,
            expandable: true,
        }
    }

    pub fn track(track: &Track, depth: i32) -> Self {
        Self {
            id: format!("track:{}", track.id.0.to_base62()),
            kind: "track".to_string(),
            label: track.name.to_string(),
            meta: format!("{} | {}", track.artist_names(), track.album_name()),
            image_url: track
                .album
                .as_ref()
                .and_then(|album| album.images.front())
                .map(|image| image.url.to_string())
                .unwrap_or_default(),
            art_ascii: String::new(),
            depth,
            playable: !matches!(track.is_playable, Some(false)),
            expandable: false,
        }
    }

    pub fn album(album: &Album, depth: i32) -> Self {
        Self::route(
            format!("album:{}", album.id),
            "album",
            album.name.to_string(),
            album
                .artists
                .front()
                .map(|artist| artist.name.to_string())
                .unwrap_or_default(),
            depth,
        )
    }

    pub fn playlist(playlist: &Playlist, depth: i32) -> Self {
        Self::route(
            format!("playlist:{}", playlist.id),
            "playlist",
            playlist.name.to_string(),
            playlist.owner.display_name.to_string(),
            depth,
        )
    }

    pub fn artist(artist: &Artist, depth: i32) -> Self {
        Self::route(
            format!("artist:{}", artist.id),
            "artist",
            artist.name.to_string(),
            "artist",
            depth,
        )
    }

    pub fn show(show: &Show, depth: i32) -> Self {
        Self::route(
            format!("show:{}", show.id),
            "show",
            show.name.to_string(),
            show.publisher.to_string(),
            depth,
        )
    }

    pub fn episode(episode: &Episode, depth: i32) -> Self {
        Self {
            id: format!("episode:{}", episode.id.0.to_base62()),
            kind: "episode".to_string(),
            label: episode.name.to_string(),
            meta: episode.release(),
            image_url: String::new(),
            art_ascii: String::new(),
            depth,
            playable: false,
            expandable: false,
        }
    }
}

fn duration_ms(duration: std::time::Duration) -> i32 {
    duration.as_millis().min(i32::MAX as u128) as i32
}
