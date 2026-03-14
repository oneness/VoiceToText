use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::mpsc::Sender;
use std::time::{SystemTime, UNIX_EPOCH};

use ashpd::{
    AppID,
    desktop::global_shortcuts::{GlobalShortcuts, NewShortcut},
    register_host_app,
};
use futures_util::StreamExt;
use tokio::sync::watch;

use crate::{
    AppState, AudioCapture, ClipboardCopyError, CompletionSoundError, DesktopCapabilities,
    PwRecordRecorder, append_transcript_to_journal, build_groq_transcription_request,
    copy_to_clipboard, execute_http_request, journal_stamp, parse_transcription_response,
    play_completion_sound, probe_desktop_capabilities, resolve_home_dir, resolve_journal_dir,
};

pub const TOGGLE_SHORTCUT_ID: &str = "toggle-recording";
pub const TOGGLE_SHORTCUT_DESCRIPTION: &str = "Start or stop voice recording";
pub const TOGGLE_SHORTCUT_TRIGGER: &str = "Alt+space";
pub const HOST_APP_ID: &str = "com.voicetotext.VoiceToText";

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DaemonEvent {
    StateChanged(AppState),
    TranscriptReady(String),
    Warning(String),
}

#[derive(Debug)]
pub enum HotkeyDaemonError {
    MissingHomeDir,
    MissingGlobalShortcutsPortal,
    InvalidAppId(String),
    DesktopEntry(std::io::Error),
    Portal(ashpd::Error),
    Recorder(crate::RecorderError),
    Transcription(crate::GroqRequestError),
    Transport(crate::TransportError),
    Journal(std::io::Error),
}

impl std::fmt::Display for HotkeyDaemonError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingHomeDir => write!(f, "HOME is not set"),
            Self::MissingGlobalShortcutsPortal => {
                write!(f, "GlobalShortcuts portal is not available on this desktop")
            }
            Self::InvalidAppId(app_id) => write!(f, "invalid portal app id: {app_id}"),
            Self::DesktopEntry(error) => write!(f, "{error}"),
            Self::Portal(error) => write!(f, "{error}"),
            Self::Recorder(error) => write!(f, "{error}"),
            Self::Transcription(error) => write!(f, "{error}"),
            Self::Transport(error) => write!(f, "{error}"),
            Self::Journal(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for HotkeyDaemonError {}

impl From<ashpd::Error> for HotkeyDaemonError {
    fn from(value: ashpd::Error) -> Self {
        Self::Portal(value)
    }
}

impl From<crate::RecorderError> for HotkeyDaemonError {
    fn from(value: crate::RecorderError) -> Self {
        Self::Recorder(value)
    }
}

impl From<crate::GroqRequestError> for HotkeyDaemonError {
    fn from(value: crate::GroqRequestError) -> Self {
        Self::Transcription(value)
    }
}

impl From<crate::TransportError> for HotkeyDaemonError {
    fn from(value: crate::TransportError) -> Self {
        Self::Transport(value)
    }
}

impl From<std::io::Error> for HotkeyDaemonError {
    fn from(value: std::io::Error) -> Self {
        Self::Journal(value)
    }
}

pub async fn run_hotkey_daemon(
    environment: &[(String, String)],
    api_key: &str,
) -> Result<(), HotkeyDaemonError> {
    run_hotkey_daemon_with_control(environment, api_key, None, None).await
}

pub async fn run_hotkey_daemon_with_control(
    environment: &[(String, String)],
    api_key: &str,
    event_sender: Option<Sender<DaemonEvent>>,
    mut shutdown_receiver: Option<watch::Receiver<bool>>,
) -> Result<(), HotkeyDaemonError> {
    let capabilities = probe_desktop_capabilities(environment);
    ensure_daemon_capabilities(&capabilities)?;
    let home_dir = resolve_home_dir(environment).ok_or(HotkeyDaemonError::MissingHomeDir)?;
    ensure_host_desktop_entry(&home_dir).map_err(HotkeyDaemonError::DesktopEntry)?;
    let app_id: AppID = HOST_APP_ID
        .parse()
        .map_err(|_| HotkeyDaemonError::InvalidAppId(HOST_APP_ID.to_string()))?;
    eprintln!("registering host app id: {HOST_APP_ID}");
    register_host_app(app_id).await?;
    let journal_dir = resolve_journal_dir(environment, &home_dir);

    eprintln!("creating global shortcuts session...");
    let global_shortcuts = GlobalShortcuts::new().await?;
    let session = global_shortcuts.create_session().await?;
    eprintln!("binding shortcut request...");
    let shortcut = NewShortcut::new(TOGGLE_SHORTCUT_ID, TOGGLE_SHORTCUT_DESCRIPTION)
        .preferred_trigger(Some(TOGGLE_SHORTCUT_TRIGGER));
    let bind_request = global_shortcuts
        .bind_shortcuts(&session, &[shortcut], None)
        .await?;
    eprintln!("awaiting bind response...");
    let bind_response = bind_request.response()?;

    eprintln!("global shortcut session created: {:?}", session);
    for shortcut in bind_response.shortcuts() {
        eprintln!(
            "shortcut bound: id={} trigger={}",
            shortcut.id(),
            shortcut.trigger_description()
        );
    }
    eprintln!("waiting for shortcut activations...");
    send_daemon_event(&event_sender, DaemonEvent::StateChanged(AppState::Idle));

    let mut activated = global_shortcuts.receive_activated().await?;
    let mut closed = session.receive_closed().await?;
    let mut active_recording: Option<PwRecordRecorder> = None;

    loop {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => {
                eprintln!("received Ctrl+C, closing session");
                stop_active_recording(active_recording.take());
                let _ = session.close().await;
                return Ok(());
            }
            _ = async {
                match &mut shutdown_receiver {
                    Some(receiver) => {
                        let _ = receiver.changed().await;
                    }
                    None => std::future::pending::<()>().await,
                }
            } => {
                if shutdown_receiver.as_ref().is_some_and(|receiver| *receiver.borrow()) {
                    eprintln!("received shutdown request, closing session");
                    stop_active_recording(active_recording.take());
                    let _ = session.close().await;
                    return Ok(());
                }
            }
            maybe_closed = closed.next() => {
                if maybe_closed.is_some() {
                    eprintln!("portal session closed");
                    return Ok(());
                }
            }
            maybe_activation = activated.next() => {
                if let Some(event) = maybe_activation {
                    if event.shortcut_id() != TOGGLE_SHORTCUT_ID {
                        continue;
                    }

                    match active_recording.take() {
                        None => {
                            let output_path = crate::temp_recording_path();
                            let recorder = PwRecordRecorder::start(output_path)?;
                            eprintln!("recording started");
                            send_daemon_event(&event_sender, DaemonEvent::StateChanged(AppState::Recording));
                            active_recording = Some(recorder);
                        }
                        Some(recorder) => {
                            eprintln!("recording stopped, transcribing...");
                            send_daemon_event(&event_sender, DaemonEvent::StateChanged(AppState::Transcribing));
                            let audio = recorder.stop()?;
                            let api_key = api_key.to_string();
                            let journal_dir = journal_dir.clone();
                            let result = tokio::task::spawn_blocking(move || {
                                handle_completed_recording(audio, &api_key, &journal_dir)
                            })
                            .await
                            .map_err(|error| {
                                HotkeyDaemonError::Journal(std::io::Error::other(error.to_string()))
                            })?;

                            match result {
                                Ok(outcome) => {
                                    send_daemon_event(
                                        &event_sender,
                                        DaemonEvent::TranscriptReady(outcome.transcript),
                                    );
                                }
                                Err(error) => {
                                    let message = error.to_string();
                                    eprintln!("warning: {message}");
                                    send_daemon_event(&event_sender, DaemonEvent::Warning(message));
                                }
                            }

                            send_daemon_event(&event_sender, DaemonEvent::StateChanged(AppState::Idle));
                        }
                    }
                }
            }
        }
    }
}

fn ensure_daemon_capabilities(capabilities: &DesktopCapabilities) -> Result<(), HotkeyDaemonError> {
    if !capabilities.has_global_shortcuts_portal {
        return Err(HotkeyDaemonError::MissingGlobalShortcutsPortal);
    }

    Ok(())
}

pub(crate) fn ensure_host_desktop_entry(home_dir: &Path) -> std::io::Result<PathBuf> {
    let desktop_dir = home_dir.join(".local/share/applications");
    fs::create_dir_all(&desktop_dir)?;

    let desktop_path = desktop_dir.join(format!("{HOST_APP_ID}.desktop"));
    let current_exe = env::current_exe()?;
    let exec = format!("{} daemon", current_exe.display());
    let desired = format!(
        "[Desktop Entry]\nType=Application\nVersion=1.0\nName=VoiceToText Linux\nComment=Voice transcription hotkey daemon\nExec={exec}\nTerminal=false\nNoDisplay=true\nCategories=Utility;\nStartupNotify=false\n"
    );

    let should_write = match fs::read_to_string(&desktop_path) {
        Ok(existing) => existing != desired,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => true,
        Err(error) => return Err(error),
    };

    if should_write {
        fs::write(&desktop_path, desired)?;
    }

    Ok(desktop_path)
}

fn handle_completed_recording(
    audio: AudioCapture,
    api_key: &str,
    journal_dir: &PathBuf,
) -> Result<CompletedRecordingOutcome, HotkeyDaemonError> {
    let transcript = transcribe_audio_capture(&audio, api_key)?;
    let stamp = journal_stamp(chrono::Local::now());
    let journal_path = append_transcript_to_journal(journal_dir, &stamp, &transcript)?;

    match copy_to_clipboard(&transcript) {
        Ok(method) => {
            eprintln!("copied transcript to clipboard via {:?}", method);
            match play_completion_sound() {
                Ok(_) => eprintln!("played completion sound"),
                Err(CompletionSoundError::MissingBundledSound(_)) => {
                    eprintln!("warning: bundled completion sound is missing; sound skipped")
                }
                Err(error) => eprintln!("warning: failed to play completion sound: {error}"),
            }
        }
        Err(ClipboardCopyError::NoSupportedCommand) => {
            eprintln!("warning: no supported clipboard command found; transcript was not copied")
        }
        Err(error) => eprintln!("warning: failed to copy transcript to clipboard: {error}"),
    }

    eprintln!("journal: {}", journal_path.display());
    println!("{transcript}");
    Ok(CompletedRecordingOutcome {
        transcript,
        journal_path,
    })
}

#[derive(Debug)]
struct CompletedRecordingOutcome {
    transcript: String,
    #[allow(dead_code)]
    journal_path: PathBuf,
}

fn stop_active_recording(recorder: Option<PwRecordRecorder>) {
    if let Some(recorder) = recorder {
        if let Err(error) = recorder.stop() {
            eprintln!("warning: failed to stop active recording during shutdown: {error}");
        }
    }
}

fn send_daemon_event(event_sender: &Option<Sender<DaemonEvent>>, event: DaemonEvent) {
    if let Some(sender) = event_sender {
        let _ = sender.send(event);
    }
}

pub fn transcribe_audio_capture(
    audio: &AudioCapture,
    api_key: &str,
) -> Result<String, HotkeyDaemonError> {
    let boundary = format!(
        "Boundary-{}",
        SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos()
    );
    let request = build_groq_transcription_request(
        audio,
        &crate::GroqRequestOptions::new(api_key),
        &boundary,
    )?;
    let response_body = execute_http_request(request)?;
    let transcript = parse_transcription_response(&response_body)?;
    Ok(transcript)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn daemon_capability_check_requires_global_shortcuts_portal() {
        let capabilities = DesktopCapabilities {
            has_global_shortcuts_portal: false,
        };

        let error = ensure_daemon_capabilities(&capabilities).unwrap_err();
        assert!(matches!(
            error,
            HotkeyDaemonError::MissingGlobalShortcutsPortal
        ));
    }

    #[test]
    fn desktop_entry_path_uses_host_app_id() {
        let path = Path::new("/home/tester")
            .join(".local/share/applications")
            .join(format!("{HOST_APP_ID}.desktop"));
        assert!(
            path.file_name()
                .and_then(|name| name.to_str())
                .unwrap_or_default()
                .contains(HOST_APP_ID)
        );
    }

    #[test]
    fn daemon_event_transcript_ready_keeps_transcript_text() {
        let event = DaemonEvent::TranscriptReady("hello world".to_string());
        assert_eq!(
            event,
            DaemonEvent::TranscriptReady("hello world".to_string())
        );
    }

    #[test]
    fn completed_recording_outcome_keeps_journal_path() {
        let outcome = CompletedRecordingOutcome {
            transcript: "hello".to_string(),
            journal_path: PathBuf::from("/tmp/journal.md"),
        };

        assert_eq!(outcome.journal_path, PathBuf::from("/tmp/journal.md"));
    }
}
