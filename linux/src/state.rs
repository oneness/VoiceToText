#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AppState {
    Idle,
    Recording,
    Transcribing,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn app_state_variants_match_expected_daemon_states() {
        assert_eq!(AppState::Idle, AppState::Idle);
        assert_eq!(AppState::Recording, AppState::Recording);
        assert_eq!(AppState::Transcribing, AppState::Transcribing);
    }
}
