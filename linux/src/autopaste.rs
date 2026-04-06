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
    },
}

struct RemoteDesktopSession {
    portal: RemoteDesktop<'static>,
    session: Session<'static, RemoteDesktop<'static>>,
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
        let session_type = env_value(environment, "XDG_SESSION_TYPE").unwrap_or_default();
        let desktop = env_value(environment, "XDG_CURRENT_DESKTOP").unwrap_or_default();

        let backend = if session_type == "wayland" && desktop.contains("GNOME") {
            AutoPasteBackend::Portal { session: None }
        } else {
            AutoPasteBackend::Unsupported
        };

        Self { backend }
    }

    pub async fn paste_clipboard(&mut self) -> Result<AutoPasteStatus, AutoPasteError> {
        match &mut self.backend {
            AutoPasteBackend::Unsupported => Ok(AutoPasteStatus::Skipped),
            AutoPasteBackend::Portal { session } => {
                if session.is_none() {
                    *session = Some(create_remote_desktop_session().await?);
                }

                if let Some(remote_session) = session.as_mut() {
                    if let Err(error) = send_paste_shortcut(remote_session).await {
                        *session = None;
                        return Err(error);
                    }
                }

                Ok(AutoPasteStatus::Pasted)
            }
        }
    }
}

async fn create_remote_desktop_session() -> Result<RemoteDesktopSession, AutoPasteError> {
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
            None,
            PersistMode::Application,
        )
        .await
        .map_err(|error| {
            AutoPasteError::Setup(format!("failed to request keyboard control: {error}"))
        })?
        .response()
        .map_err(|error| {
            AutoPasteError::Setup(format!("keyboard control was not granted: {error}"))
        })?;

    portal
        .start(&session, None)
        .await
        .map_err(|error| {
            AutoPasteError::Setup(format!("failed to start auto-paste session: {error}"))
        })?
        .response()
        .map_err(|error| {
            AutoPasteError::Setup(format!("auto-paste session was not approved: {error}"))
        })?;

    Ok(RemoteDesktopSession { portal, session })
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
    fn controller_skips_auto_paste_off_gnome_wayland() {
        let environment = vec![
            ("XDG_SESSION_TYPE".to_string(), "x11".to_string()),
            ("XDG_CURRENT_DESKTOP".to_string(), "GNOME".to_string()),
        ];

        let controller = AutoPasteController::new(&environment);

        assert!(matches!(controller.backend, AutoPasteBackend::Unsupported));
    }
}
