#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum QtFeatureState {
    Available,
    InProgress,
    LegacyReference,
}

#[derive(Clone, Copy, Debug)]
pub struct QtFeature {
    pub name: &'static str,
    pub state: QtFeatureState,
    pub route: &'static str,
}

pub const CORE_SCREENS: &[QtFeature] = &[
    QtFeature {
        name: "Home",
        state: QtFeatureState::InProgress,
        route: "home",
    },
    QtFeature {
        name: "Library",
        state: QtFeatureState::Available,
        route: "library",
    },
    QtFeature {
        name: "Search",
        state: QtFeatureState::Available,
        route: "search",
    },
    QtFeature {
        name: "Playlists",
        state: QtFeatureState::Available,
        route: "playlists",
    },
    QtFeature {
        name: "Albums",
        state: QtFeatureState::Available,
        route: "albums",
    },
    QtFeature {
        name: "Artists",
        state: QtFeatureState::Available,
        route: "artists",
    },
    QtFeature {
        name: "Account",
        state: QtFeatureState::InProgress,
        route: "login",
    },
];

pub const PARITY_FEATURES: &[QtFeature] = &[
    QtFeature {
        name: "Playback",
        state: QtFeatureState::Available,
        route: "playback",
    },
    QtFeature {
        name: "Lyrics",
        state: QtFeatureState::InProgress,
        route: "lyrics",
    },
    QtFeature {
        name: "Credits",
        state: QtFeatureState::LegacyReference,
        route: "credits",
    },
    QtFeature {
        name: "Recommendations",
        state: QtFeatureState::LegacyReference,
        route: "recommendations",
    },
    QtFeature {
        name: "Finder",
        state: QtFeatureState::LegacyReference,
        route: "finder",
    },
    QtFeature {
        name: "Artwork",
        state: QtFeatureState::LegacyReference,
        route: "artwork",
    },
    QtFeature {
        name: "Last.fm",
        state: QtFeatureState::LegacyReference,
        route: "lastfm",
    },
];
