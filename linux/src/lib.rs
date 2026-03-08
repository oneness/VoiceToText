mod config;
mod desktop;
mod groq;
mod hotkey_daemon;
mod journal;
mod platform;
mod recorder;
mod state;
mod transport;

pub use config::{Config, parse_api_key_from_config, resolve_api_key, resolve_config_path};
pub use desktop::{DesktopCapabilities, probe_desktop_capabilities};
pub use groq::{
    AudioCapture, DEFAULT_GROQ_MODEL, GROQ_TRANSCRIPTIONS_URL, GroqRequestError,
    GroqRequestOptions, HttpRequest, build_groq_transcription_request,
    parse_transcription_response,
};
pub use hotkey_daemon::{
    HotkeyDaemonError, TOGGLE_SHORTCUT_DESCRIPTION, TOGGLE_SHORTCUT_ID, TOGGLE_SHORTCUT_TRIGGER,
    run_hotkey_daemon, transcribe_audio_capture,
};
pub use journal::{journal_file_name, render_journal_entry};
pub use platform::{
    ClipboardCopyError, ClipboardCopyMethod, JournalStamp, append_transcript_to_journal,
    copy_to_clipboard, current_environment, guess_mime_type, journal_stamp, load_config_json,
    resolve_home_dir, resolve_journal_dir,
};
pub use recorder::{
    AudioSource, DEFAULT_RECORD_SECONDS, PwRecordCommand, PwRecordRecorder, RecorderError,
    SOURCE_ENV_KEY, list_audio_sources, record_for_duration, temp_recording_path,
};
pub use state::AppState;
pub use transport::{TransportError, execute_http_request};
