use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

use ashpd::desktop::{
    PersistMode, Session,
    remote_desktop::{DeviceType, KeyState, RemoteDesktop},
};

const KEYSYM_CONTROL_L: i32 = 0xffe3;
const KEYSYM_Y: i32 = 0x79;
const CLIPBOARD_SETTLE_DELAY_MS: u64 = 60;
const KEY_CHORD_DELAY_MS: u64 = 12;

pub(crate) struct AutoPasteController {
    backend: AutoPasteBackend,
}

enum AutoPasteBackend {
    Unsupported,
    Portal {
        session: Option<RemoteDesktopSession>,
        restore_token_path: Option<PathBuf>,
    },
}

struct RemoteDesktopSession {
    portal: RemoteDesktop<'static>,
    session: Session<'static, RemoteDesktop<'static>>,
    restore_token: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum AutoPasteStatus {
    Pasted,
    Skipped,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) enum AutoPasteError {
    Setup(String),
    Runtime(String),
}

impl std::fmt::Display for AutoPasteError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Setup(message) | Self::Runtime(message) => f.write_str(message),
        }
    }
}

impl std::error::Error for AutoPasteError {}

impl AutoPasteController {
    pub fn new(environment: &[(String, String)]) -> Self {
        let restore_token_path = resolve_restore_token_path(environment);
        Self::with_restore_token_path(environment, restore_token_path)
    }

    pub fn with_restore_token_path(
        environment: &[(String, String)],
        restore_token_path: Option<PathBuf>,
    ) -> Self {
        let session_type = env_value(environment, "XDG_SESSION_TYPE").unwrap_or_default();
        let desktop = env_value(environment, "XDG_CURRENT_DESKTOP").unwrap_or_default();

        let backend = if session_type == "wayland" && desktop.contains("GNOME") {
            AutoPasteBackend::Portal {
                session: None,
                restore_token_path,
            }
        } else {
            AutoPasteBackend::Unsupported
        };

        Self { backend }
    }

    pub async fn paste_clipboard(&mut self) -> Result<AutoPasteStatus, AutoPasteError> {
        match &mut self.backend {
            AutoPasteBackend::Unsupported => Ok(AutoPasteStatus::Skipped),
            AutoPasteBackend::Portal {
                session,
                restore_token_path,
            } => {
                if session.is_none() {
                    let token = restore_token_path
                        .as_deref()
                        .and_then(load_restore_token);
                    let new_session = create_remote_desktop_session(token.as_deref()).await?;
                    if let (Some(path), Some(new_token)) =
                        (restore_token_path.as_deref(), new_session.restore_token.as_deref())
                    {
                        if token.as_deref() != Some(new_token) {
                            if let Err(error) = save_restore_token(path, new_token) {
                                eprintln!(
                                    "warning: failed to persist auto-paste restore token to {}: {error}",
                                    path.display()
                                );
                            }
                        }
                    }
                    *session = Some(new_session);
                }

                if let Some(remote_session) = session.as_mut() {
                    if let Err(error) = send_paste_shortcut(remote_session).await {
                        // Session is invalid (e.g. after suspend/resume). Drop it so the
                        // next attempt will transparently re-create it using the persisted
                        // restore token, without re-prompting the user.
                        *session = None;
                        return Err(error);
                    }
                }

                Ok(AutoPasteStatus::Pasted)
            }
        }
    }
}

async fn create_remote_desktop_session(
    restore_token: Option<&str>,
) -> Result<RemoteDesktopSession, AutoPasteError> {
    let portal = RemoteDesktop::new().await.map_err(|error| {
        AutoPasteError::Setup(format!("auto-paste portal unavailable: {error}"))
    })?;
    let session = portal.create_session().await.map_err(|error| {
        AutoPasteError::Setup(format!("failed to create auto-paste session: {error}"))
    })?;

    portal
        .select_devices(
            &session,
            DeviceType::Keyboard.into(),
            restore_token,
            PersistMode::ExplicitlyRevoked,
        )
        .await
        .map_err(|error| {
            AutoPasteError::Setup(format!("failed to request keyboard control: {error}"))
        })?
        .response()
        .map_err(|error| {
            AutoPasteError::Setup(format!("keyboard control was not granted: {error}"))
        })?;

    let selected = portal
        .start(&session, None)
        .await
        .map_err(|error| {
            AutoPasteError::Setup(format!("failed to start auto-paste session: {error}"))
        })?
        .response()
        .map_err(|error| {
            AutoPasteError::Setup(format!("auto-paste session was not approved: {error}"))
        })?;

    let restore_token = selected.restore_token().map(|value| value.to_string());

    Ok(RemoteDesktopSession {
        portal,
        session,
        restore_token,
    })
}

async fn send_paste_shortcut(session: &mut RemoteDesktopSession) -> Result<(), AutoPasteError> {
    tokio::time::sleep(Duration::from_millis(CLIPBOARD_SETTLE_DELAY_MS)).await;
    send_keysym(
        &session.portal,
        &session.session,
        KEYSYM_CONTROL_L,
        KeyState::Pressed,
    )
    .await?;
    tokio::time::sleep(Duration::from_millis(KEY_CHORD_DELAY_MS)).await;
    send_keysym(
        &session.portal,
        &session.session,
        KEYSYM_Y,
        KeyState::Pressed,
    )
    .await?;
    tokio::time::sleep(Duration::from_millis(KEY_CHORD_DELAY_MS)).await;
    send_keysym(
        &session.portal,
        &session.session,
        KEYSYM_Y,
        KeyState::Released,
    )
    .await?;
    send_keysym(
        &session.portal,
        &session.session,
        KEYSYM_CONTROL_L,
        KeyState::Released,
    )
    .await?;
    Ok(())
}

async fn send_keysym(
    portal: &RemoteDesktop<'static>,
    session: &Session<'static, RemoteDesktop<'static>>,
    keysym: i32,
    state: KeyState,
) -> Result<(), AutoPasteError> {
    portal
        .notify_keyboard_keysym(session, keysym, state)
        .await
        .map_err(|error| {
            AutoPasteError::Runtime(format!("failed to inject paste shortcut: {error}"))
        })
}

fn env_value(environment: &[(String, String)], key: &str) -> Option<String> {
    environment
        .iter()
        .find(|(candidate, _)| candidate == key)
        .map(|(_, value)| value.clone())
}

fn resolve_restore_token_path(environment: &[(String, String)]) -> Option<PathBuf> {
    if let Some(override_path) = env_value(environment, "VOICETOTEXT_AUTOPASTE_TOKEN_PATH") {
        let home = env_value(environment, "HOME").map(PathBuf::from);
        return Some(expand_home(&override_path, home.as_deref()));
    }

    let home = env_value(environment, "HOME").map(PathBuf::from)?;
    let base_dir = env_value(environment, "XDG_STATE_HOME")
        .map(|value| expand_home(&value, Some(home.as_path())))
        .unwrap_or_else(|| home.join(".local/state"));
    Some(base_dir.join("voicetotext").join("autopaste-restore-token"))
}

fn expand_home(path: &str, home_dir: Option<&Path>) -> PathBuf {
    if let Some(home) = home_dir {
        if path == "~" {
            return home.to_path_buf();
        }
        if let Some(stripped) = path.strip_prefix("~/") {
            return home.join(stripped);
        }
    }
    PathBuf::from(path)
}

fn load_restore_token(path: &Path) -> Option<String> {
    let contents = fs::read_to_string(path).ok()?;
    let trimmed = contents.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

fn save_restore_token(path: &Path, token: &str) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    // Write then attempt to tighten permissions so the token is not world-readable.
    fs::write(path, token)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o600));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn controller_uses_portal_backend_for_gnome_wayland() {
        let environment = vec![
            ("XDG_SESSION_TYPE".to_string(), "wayland".to_string()),
            ("XDG_CURRENT_DESKTOP".to_string(), "GNOME".to_string()),
        ];

        let controller = AutoPasteController::new(&environment);

        assert!(matches!(
            controller.backend,
            AutoPasteBackend::Portal { .. }
        ));
    }

    #[test]
    fn restore_token_path_respects_xdg_state_home() {
        let environment = vec![
            ("HOME".to_string(), "/home/tester".to_string()),
            (
                "XDG_STATE_HOME".to_string(),
                "/home/tester/.state".to_string(),
            ),
        ];

        let path = resolve_restore_token_path(&environment).unwrap();

        assert_eq!(
            path,
            PathBuf::from("/home/tester/.state/voicetotext/autopaste-restore-token")
        );
    }

    #[test]
    fn restore_token_path_defaults_to_local_state() {
        let environment = vec![("HOME".to_string(), "/home/tester".to_string())];

        let path = resolve_restore_token_path(&environment).unwrap();

        assert_eq!(
            path,
            PathBuf::from("/home/tester/.local/state/voicetotext/autopaste-restore-token")
        );
    }

    #[test]
    fn restore_token_override_path_wins() {
        let environment = vec![
            ("HOME".to_string(), "/home/tester".to_string()),
            (
                "VOICETOTEXT_AUTOPASTE_TOKEN_PATH".to_string(),
                "~/custom-token".to_string(),
            ),
        ];

        let path = resolve_restore_token_path(&environment).unwrap();

        assert_eq!(path, PathBuf::from("/home/tester/custom-token"));
    }

    #[test]
    fn load_and_save_restore_token_roundtrip() {
        let tmp = std::env::temp_dir().join(format!(
            "voicetotext-autopaste-token-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let path = tmp.join("autopaste-restore-token");

        save_restore_token(&path, "abc-123").unwrap();
        let loaded = load_restore_token(&path);
        assert_eq!(loaded.as_deref(), Some("abc-123"));

        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn controller_skips_auto_paste_off_gnome_wayland() {
        let environment = vec![
            ("XDG_SESSION_TYPE".to_string(), "x11".to_string()),
            ("XDG_CURRENT_DESKTOP".to_string(), "GNOME".to_string()),
        ];

        let controller = AutoPasteController::new(&environment);

        assert!(matches!(controller.backend, AutoPasteBackend::Unsupported));
    }
}
