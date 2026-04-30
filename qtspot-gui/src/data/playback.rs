use serde::{Deserialize, Serialize};

#[derive(Default, Copy, Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum QueueBehavior {
    #[default]
    Sequential,
    Random,
    LoopTrack,
    LoopAll,
}
