use std::sync::Arc;

use serde::Deserialize;

#[derive(Clone, Deserialize)]
pub struct UserProfile {
    pub display_name: Arc<str>,
    pub email: Arc<str>,
    pub id: Arc<str>,
}

#[derive(Clone, Deserialize, Debug)]
pub struct PublicUser {
    pub display_name: Arc<str>,
    pub id: Arc<str>,
}
