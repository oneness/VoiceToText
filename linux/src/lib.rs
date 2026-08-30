mod config;
mod desktop;
mod engine;
mod groq;
mod hotkey_daemon;
mod journal;
mod platform;
mod recorder;
mod state;
mod transport;
mod tray_app;

pub use config::{Config, TranscriptionBackendChoice, resolve_config_path};
pub use desktop::{DesktopCapabilities, probe_desktop_capabilities};
pub use engine::{
    DEFAULT_LOCAL_MODEL_FILE, DEFAULT_LOCAL_MODEL_URL, LocalTranscribeError, LocalTranscriber,
    TranscriptionEngine,
};
pub use groq::{
    AudioCapture, DEFAULT_GROQ_MODEL, GROQ_MAX_UPLOAD_BYTES, GROQ_TRANSCRIPTIONS_URL,
    GroqRequestError, GroqRequestOptions, HttpRequest, build_groq_transcription_request,
    parse_transcription_response,
};
pub use hotkey_daemon::{
    DaemonCommand, DaemonEvent, HOST_APP_ID, HotkeyDaemonError, TOGGLE_SHORTCUT_DESCRIPTION,
    TOGGLE_SHORTCUT_ID, TOGGLE_SHORTCUT_TRIGGER, run_hotkey_daemon, run_hotkey_daemon_with_control,
    transcribe_audio_capture,
};
pub use journal::{journal_file_name, render_journal_entry};
pub use platform::{
    ClipboardCopyError, ClipboardCopyMethod, CompletionSoundError, CompletionSoundMethod,
    JournalStamp, append_transcript_to_journal, copy_to_clipboard, current_environment,
    guess_mime_type, install_linux_icon_assets, journal_stamp, load_config_json,
    play_completion_sound, resolve_home_dir, resolve_journal_dir,
};
pub use recorder::{
    AudioSource, DEFAULT_RECORD_SECONDS, PwRecordCommand, PwRecordRecorder, RecorderError,
    SOURCE_ENV_KEY, list_audio_sources, record_for_duration, temp_recording_path,
};
pub use state::AppState;
pub use transport::{TransportError, execute_http_request};
pub use tray_app::run_tray_daemon;
