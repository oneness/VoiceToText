use std::ffi::OsString;
use std::fs;
use std::path::PathBuf;
use std::process;
use std::time::Duration;

use chrono::Local;
use voicetotext_linux_core::{
    AudioCapture, ClipboardCopyError, DEFAULT_RECORD_SECONDS, SOURCE_ENV_KEY, copy_to_clipboard,
    current_environment, guess_mime_type, journal_stamp, list_audio_sources, load_config_json,
    play_completion_sound, record_for_duration, resolve_api_key, resolve_config_path,
    resolve_home_dir, resolve_journal_dir, run_hotkey_daemon, transcribe_audio_capture,
};

enum CliCommand {
    TranscribeFile(PathBuf),
    RecordThenTranscribe { seconds: u64 },
    Daemon,
    Sources,
}

fn main() {
    if let Err(error) = run() {
        eprintln!("error: {error}");
        process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let command = parse_command(std::env::args_os())?;
    let environment = current_environment();
    if matches!(command, CliCommand::Sources) {
        print_sources()?;
        return Ok(());
    }

    let home_dir = resolve_home_dir(&environment).ok_or("HOME is not set")?;
    let config_path = resolve_config_path(&environment, &home_dir);
    let config_json = load_config_json(&config_path)?;
    let api_key = resolve_api_key(&environment, config_json.as_deref())
        .ok_or("Groq API key not configured")?;

    if matches!(command, CliCommand::Daemon) {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()?;
        runtime.block_on(run_hotkey_daemon(&environment, &api_key))?;
        return Ok(());
    }

    let audio = match command {
        CliCommand::TranscribeFile(audio_path) => load_audio_capture(&audio_path)?,
        CliCommand::RecordThenTranscribe { seconds } => {
            eprintln!("recording for {seconds} seconds...");
            record_for_duration(Duration::from_secs(seconds))?
        }
        CliCommand::Daemon => unreachable!("daemon mode returns before audio loading"),
        CliCommand::Sources => unreachable!("sources mode returns before audio loading"),
    };

    let transcript = transcribe_audio_capture(&audio, &api_key)?;

    let journal_dir = resolve_journal_dir(&environment, &home_dir);
    let stamp = journal_stamp(Local::now());
    let journal_path =
        voicetotext_linux_core::append_transcript_to_journal(&journal_dir, &stamp, &transcript)?;

    match copy_to_clipboard(&transcript) {
        Ok(method) => {
            eprintln!("copied transcript to clipboard via {:?}", method);
            if let Err(error) = play_completion_sound() {
                eprintln!("warning: failed to play completion sound: {error}");
            }
        }
        Err(ClipboardCopyError::NoSupportedCommand) => {
            eprintln!("warning: no supported clipboard command found; transcript was not copied")
        }
        Err(error) => eprintln!("warning: failed to copy transcript to clipboard: {error}"),
    }

    println!("{transcript}");
    eprintln!("journal: {}", journal_path.display());
    Ok(())
}

fn load_audio_capture(audio_path: &PathBuf) -> Result<AudioCapture, Box<dyn std::error::Error>> {
    let audio_bytes = fs::read(audio_path)?;
    let file_name = audio_path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or("invalid audio file name")?;
    Ok(AudioCapture::new(
        file_name,
        guess_mime_type(audio_path),
        audio_bytes,
        Some(audio_path.clone()),
    ))
}

fn parse_command<I>(args: I) -> Result<CliCommand, Box<dyn std::error::Error>>
where
    I: IntoIterator<Item = OsString>,
{
    let mut args = args.into_iter();
    let _program = args.next();
    let first = args.next().ok_or(usage())?;

    if first == "record" {
        let seconds = match args.next() {
            Some(value) => value
                .into_string()
                .map_err(|_| usage())?
                .parse::<u64>()
                .map_err(|_| usage())?,
            None => DEFAULT_RECORD_SECONDS,
        };

        if args.next().is_some() {
            return Err(usage().into());
        }

        return Ok(CliCommand::RecordThenTranscribe { seconds });
    }

    if first == "daemon" {
        if args.next().is_some() {
            return Err(usage().into());
        }

        return Ok(CliCommand::Daemon);
    }

    if first == "sources" {
        if args.next().is_some() {
            return Err(usage().into());
        }

        return Ok(CliCommand::Sources);
    }

    if args.next().is_some() {
        return Err(usage().into());
    }

    Ok(CliCommand::TranscribeFile(PathBuf::from(first)))
}

fn usage() -> &'static str {
    "usage: voicetotext-linux-core <audio-file-path> | voicetotext-linux-core record [seconds] | voicetotext-linux-core daemon | voicetotext-linux-core sources"
}

fn print_sources() -> Result<(), Box<dyn std::error::Error>> {
    let sources = list_audio_sources()?;
    for source in sources {
        let default_marker = if source.is_default { "*" } else { " " };
        println!(
            "{default_marker} id={} name={} description={}",
            source.id, source.name, source.description
        );
    }
    println!("set {SOURCE_ENV_KEY} to the desired source name before running record or daemon");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_command_accepts_file_path_mode() {
        let command = parse_command([
            OsString::from("voicetotext-linux-core"),
            OsString::from("/tmp/test.wav"),
        ])
        .unwrap();

        match command {
            CliCommand::TranscribeFile(path) => assert_eq!(path, PathBuf::from("/tmp/test.wav")),
            CliCommand::RecordThenTranscribe { .. } | CliCommand::Daemon | CliCommand::Sources => {
                panic!("expected file mode")
            }
        }
    }

    #[test]
    fn parse_command_uses_default_record_duration() {
        let command = parse_command([
            OsString::from("voicetotext-linux-core"),
            OsString::from("record"),
        ])
        .unwrap();

        match command {
            CliCommand::RecordThenTranscribe { seconds } => {
                assert_eq!(seconds, DEFAULT_RECORD_SECONDS)
            }
            CliCommand::TranscribeFile(_) | CliCommand::Daemon | CliCommand::Sources => {
                panic!("expected record mode")
            }
        }
    }

    #[test]
    fn parse_command_accepts_custom_record_duration() {
        let command = parse_command([
            OsString::from("voicetotext-linux-core"),
            OsString::from("record"),
            OsString::from("7"),
        ])
        .unwrap();

        match command {
            CliCommand::RecordThenTranscribe { seconds } => assert_eq!(seconds, 7),
            CliCommand::TranscribeFile(_) | CliCommand::Daemon | CliCommand::Sources => {
                panic!("expected record mode")
            }
        }
    }

    #[test]
    fn parse_command_accepts_daemon_mode() {
        let command = parse_command([
            OsString::from("voicetotext-linux-core"),
            OsString::from("daemon"),
        ])
        .unwrap();

        match command {
            CliCommand::Daemon => {}
            CliCommand::TranscribeFile(_)
            | CliCommand::RecordThenTranscribe { .. }
            | CliCommand::Sources => panic!("expected daemon mode"),
        }
    }

    #[test]
    fn parse_command_accepts_sources_mode() {
        let command = parse_command([
            OsString::from("voicetotext-linux-core"),
            OsString::from("sources"),
        ])
        .unwrap();

        match command {
            CliCommand::Sources => {}
            CliCommand::TranscribeFile(_)
            | CliCommand::RecordThenTranscribe { .. }
            | CliCommand::Daemon => panic!("expected sources mode"),
        }
    }
}
