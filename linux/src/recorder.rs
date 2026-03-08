use std::env;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use crate::AudioCapture;

pub const DEFAULT_RECORD_SECONDS: u64 = 5;
pub const SOURCE_ENV_KEY: &str = "VOICETOTEXT_SOURCE";

#[derive(Debug)]
pub enum RecorderError {
    Spawn(io::Error),
    Signal(io::Error),
    Wait(io::Error),
    MissingOutput(PathBuf),
    Read(io::Error),
}

impl std::fmt::Display for RecorderError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Spawn(error) => write!(f, "failed to start pw-record: {error}"),
            Self::Signal(error) => write!(f, "failed to stop pw-record: {error}"),
            Self::Wait(error) => write!(f, "failed while waiting for pw-record: {error}"),
            Self::MissingOutput(path) => {
                write!(f, "pw-record did not produce output at {}", path.display())
            }
            Self::Read(error) => write!(f, "failed to read recorded audio: {error}"),
        }
    }
}

impl std::error::Error for RecorderError {}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PwRecordCommand {
    pub program: &'static str,
    pub args: Vec<String>,
}

impl PwRecordCommand {
    pub fn for_output(output_path: &Path, target: Option<&str>) -> Self {
        let mut args = vec![
            output_path.display().to_string(),
            "--rate".to_string(),
            "16000".to_string(),
            "--channels".to_string(),
            "1".to_string(),
            "--format".to_string(),
            "s16".to_string(),
        ];

        if let Some(target) = target.filter(|value| !value.trim().is_empty()) {
            args.push("--target".to_string());
            args.push(target.to_string());
        }

        Self {
            program: "pw-record",
            args,
        }
    }
}

pub struct PwRecordRecorder {
    child: Child,
    output_path: PathBuf,
}

impl PwRecordRecorder {
    pub fn start(output_path: PathBuf) -> Result<Self, RecorderError> {
        let target = env::var(SOURCE_ENV_KEY).ok();
        Self::start_with_target(output_path, target.as_deref())
    }

    pub fn start_with_target(
        output_path: PathBuf,
        target: Option<&str>,
    ) -> Result<Self, RecorderError> {
        let command = PwRecordCommand::for_output(&output_path, target);
        let child = Command::new(command.program)
            .args(&command.args)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .map_err(RecorderError::Spawn)?;

        Ok(Self { child, output_path })
    }

    pub fn stop(mut self) -> Result<AudioCapture, RecorderError> {
        send_sigint(self.child.id()).map_err(RecorderError::Signal)?;
        self.child.wait().map_err(RecorderError::Wait)?;

        if !self.output_path.exists() {
            return Err(RecorderError::MissingOutput(self.output_path));
        }

        let bytes = fs::read(&self.output_path).map_err(RecorderError::Read)?;
        let file_name = self
            .output_path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("recording.wav")
            .to_string();
        Ok(AudioCapture::new(
            file_name,
            "audio/wav",
            bytes,
            Some(self.output_path),
        ))
    }
}

pub fn record_for_duration(duration: Duration) -> Result<AudioCapture, RecorderError> {
    let output_path = temp_recording_path();
    let recorder = PwRecordRecorder::start(output_path)?;
    std::thread::sleep(duration);
    recorder.stop()
}

pub fn temp_recording_path() -> PathBuf {
    let suffix = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    env::temp_dir().join(format!("voicetotext-recording-{suffix}.wav"))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AudioSource {
    pub id: u32,
    pub description: String,
    pub name: String,
    pub is_default: bool,
}

pub fn list_audio_sources() -> io::Result<Vec<AudioSource>> {
    let output = Command::new("wpctl").arg("status").output()?;
    let stdout = String::from_utf8_lossy(&output.stdout);

    let mut sources = Vec::new();
    let mut in_sources = false;
    for raw_line in stdout.lines() {
        let line = raw_line.trim_end();
        let normalized = line.trim_start().trim_start_matches('│').trim_start();
        if normalized == "├─ Sources:" {
            in_sources = true;
            continue;
        }
        if in_sources && normalized == "├─ Filters:" {
            break;
        }
        if !in_sources {
            continue;
        }

        let trimmed = normalized;
        if trimmed.is_empty() {
            continue;
        }

        let is_default = trimmed.starts_with('*');
        let entry = trimmed.trim_start_matches('*').trim();
        let Some((id_part, rest)) = entry.split_once('.') else {
            continue;
        };
        let Ok(id) = id_part.trim().parse::<u32>() else {
            continue;
        };

        let description = rest
            .split('[')
            .next()
            .unwrap_or_default()
            .trim()
            .to_string();
        let name = inspect_source_name(id).unwrap_or_else(|| description.clone());

        sources.push(AudioSource {
            id,
            description,
            name,
            is_default,
        });
    }

    Ok(sources)
}

fn inspect_source_name(id: u32) -> Option<String> {
    let output = Command::new("wpctl")
        .args(["inspect", &id.to_string()])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }

    String::from_utf8_lossy(&output.stdout)
        .lines()
        .find_map(|line| {
            let trimmed = line.trim();
            trimmed
                .strip_prefix("* node.name = ")
                .map(|value| value.trim_matches('"').to_string())
        })
}

fn send_sigint(pid: u32) -> io::Result<()> {
    let result = unsafe { libc::kill(pid as i32, libc::SIGINT) };
    if result == 0 {
        Ok(())
    } else {
        Err(io::Error::last_os_error())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pw_record_command_matches_expected_audio_settings() {
        let output = Path::new("/tmp/test.wav");
        let command = PwRecordCommand::for_output(output, None);

        assert_eq!(command.program, "pw-record");
        assert_eq!(
            command.args,
            vec![
                "/tmp/test.wav",
                "--rate",
                "16000",
                "--channels",
                "1",
                "--format",
                "s16",
            ]
        );
    }

    #[test]
    fn pw_record_command_includes_target_when_provided() {
        let output = Path::new("/tmp/test.wav");
        let command = PwRecordCommand::for_output(output, Some("alsa_input.test"));

        assert_eq!(
            command.args,
            vec![
                "/tmp/test.wav",
                "--rate",
                "16000",
                "--channels",
                "1",
                "--format",
                "s16",
                "--target",
                "alsa_input.test",
            ]
        );
    }

    #[test]
    fn temp_recording_path_uses_wav_extension() {
        let path = temp_recording_path();
        assert_eq!(path.extension().and_then(|ext| ext.to_str()), Some("wav"));
        assert!(
            path.file_name()
                .and_then(|name| name.to_str())
                .unwrap_or_default()
                .starts_with("voicetotext-recording-")
        );
    }
}
