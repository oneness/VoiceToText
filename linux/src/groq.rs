use std::path::PathBuf;

pub const GROQ_TRANSCRIPTIONS_URL: &str = "https://api.groq.com/openai/v1/audio/transcriptions";
pub const DEFAULT_GROQ_MODEL: &str = "whisper-large-v3-turbo";
pub const GROQ_MAX_UPLOAD_BYTES: usize = 25 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AudioCapture {
    pub file_name: String,
    pub mime_type: String,
    pub bytes: Vec<u8>,
    pub temp_path: Option<PathBuf>,
}

impl AudioCapture {
    pub fn new(
        file_name: impl Into<String>,
        mime_type: impl Into<String>,
        bytes: Vec<u8>,
        temp_path: Option<PathBuf>,
    ) -> Self {
        Self {
            file_name: file_name.into(),
            mime_type: mime_type.into(),
            bytes,
            temp_path,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GroqRequestOptions {
    pub api_key: String,
    pub model: String,
}

impl GroqRequestOptions {
    pub fn new(api_key: impl Into<String>) -> Self {
        Self {
            api_key: api_key.into(),
            model: DEFAULT_GROQ_MODEL.to_string(),
        }
    }

    pub fn with_model(mut self, model: impl Into<String>) -> Self {
        self.model = model.into();
        self
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HttpRequest {
    pub url: String,
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
}

impl HttpRequest {
    pub fn header(&self, name: &str) -> Option<&str> {
        self.headers
            .iter()
            .find(|(key, _)| key.eq_ignore_ascii_case(name))
            .map(|(_, value)| value.as_str())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GroqRequestError {
    MissingApiKey,
    EmptyAudioData,
    EmptyBoundary,
    AudioTooLarge { request_bytes: usize, max_bytes: usize },
    InvalidResponse,
    EmptyResponseText,
}

impl std::fmt::Display for GroqRequestError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingApiKey => write!(f, "missing Groq API key"),
            Self::EmptyAudioData => write!(f, "audio payload is empty"),
            Self::EmptyBoundary => write!(f, "multipart boundary is empty"),
            Self::AudioTooLarge {
                request_bytes,
                max_bytes,
            } => write!(
                f,
                "audio upload is too large for Groq: request size {request_bytes} bytes exceeds {max_bytes} bytes"
            ),
            Self::InvalidResponse => write!(f, "invalid transcription response"),
            Self::EmptyResponseText => write!(f, "transcription response text was empty"),
        }
    }
}

impl std::error::Error for GroqRequestError {}

pub fn build_groq_transcription_request(
    audio: &AudioCapture,
    options: &GroqRequestOptions,
    boundary: &str,
) -> Result<HttpRequest, GroqRequestError> {
    validate_request_inputs(audio, options, boundary)?;
    let request_bytes = estimated_request_size(audio, options, boundary)?;
    if request_bytes > GROQ_MAX_UPLOAD_BYTES {
        return Err(GroqRequestError::AudioTooLarge {
            request_bytes,
            max_bytes: GROQ_MAX_UPLOAD_BYTES,
        });
    }

    let mut body = Vec::new();
    append_text(&mut body, &format!("--{boundary}\r\n"));
    append_text(
        &mut body,
        &format!(
            "Content-Disposition: form-data; name=\"file\"; filename=\"{}\"\r\n",
            audio.file_name
        ),
    );
    append_text(
        &mut body,
        &format!("Content-Type: {}\r\n\r\n", audio.mime_type),
    );
    body.extend_from_slice(&audio.bytes);
    append_text(&mut body, "\r\n");

    append_text(&mut body, &format!("--{boundary}\r\n"));
    append_text(
        &mut body,
        "Content-Disposition: form-data; name=\"model\"\r\n\r\n",
    );
    append_text(&mut body, &options.model);
    append_text(&mut body, "\r\n");
    append_text(&mut body, &format!("--{boundary}--\r\n"));

    Ok(HttpRequest {
        url: GROQ_TRANSCRIPTIONS_URL.to_string(),
        headers: vec![
            (
                "Authorization".to_string(),
                format!("Bearer {}", options.api_key),
            ),
            (
                "Content-Type".to_string(),
                format!("multipart/form-data; boundary={boundary}"),
            ),
        ],
        body,
    })
}

pub fn parse_transcription_response(response_body: &str) -> Result<String, GroqRequestError> {
    let parsed: serde_json::Value =
        serde_json::from_str(response_body).map_err(|_| GroqRequestError::InvalidResponse)?;

    let text = parsed
        .get("text")
        .and_then(|value| value.as_str())
        .map(str::trim)
        .ok_or(GroqRequestError::InvalidResponse)?;

    if text.is_empty() {
        return Err(GroqRequestError::EmptyResponseText);
    }

    Ok(text.to_string())
}

fn append_text(body: &mut Vec<u8>, text: &str) {
    body.extend_from_slice(text.as_bytes());
}

fn validate_request_inputs(
    audio: &AudioCapture,
    options: &GroqRequestOptions,
    boundary: &str,
) -> Result<(), GroqRequestError> {
    if options.api_key.trim().is_empty() {
        return Err(GroqRequestError::MissingApiKey);
    }

    if audio.bytes.is_empty() {
        return Err(GroqRequestError::EmptyAudioData);
    }

    if boundary.trim().is_empty() {
        return Err(GroqRequestError::EmptyBoundary);
    }

    Ok(())
}

fn estimated_request_size(
    audio: &AudioCapture,
    options: &GroqRequestOptions,
    boundary: &str,
) -> Result<usize, GroqRequestError> {
    validate_request_inputs(audio, options, boundary)?;
    Ok(multipart_overhead_len(
        &audio.file_name,
        &audio.mime_type,
        &options.model,
        boundary,
    ) + audio.bytes.len())
}

fn multipart_overhead_len(file_name: &str, mime_type: &str, model: &str, boundary: &str) -> usize {
    (format!("--{boundary}\r\n")).len()
        + (format!(
            "Content-Disposition: form-data; name=\"file\"; filename=\"{}\"\r\n",
            file_name
        ))
        .len()
        + (format!("Content-Type: {mime_type}\r\n\r\n")).len()
        + "\r\n".len()
        + (format!("--{boundary}\r\n")).len()
        + "Content-Disposition: form-data; name=\"model\"\r\n\r\n".len()
        + model.len()
        + "\r\n".len()
        + (format!("--{boundary}--\r\n")).len()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_builder_matches_current_multipart_shape() {
        let audio = AudioCapture::new(
            "clip.m4a",
            "audio/m4a",
            b"audio-bytes".to_vec(),
            Some(PathBuf::from("/tmp/clip.m4a")),
        );
        let options = GroqRequestOptions::new("secret-key");

        let request = build_groq_transcription_request(&audio, &options, "Boundary-Test").unwrap();
        let body = String::from_utf8(request.body.clone()).unwrap();

        assert_eq!(request.url, GROQ_TRANSCRIPTIONS_URL);
        assert_eq!(request.header("Authorization"), Some("Bearer secret-key"));
        assert_eq!(
            request.header("Content-Type"),
            Some("multipart/form-data; boundary=Boundary-Test")
        );
        assert!(body.contains("--Boundary-Test\r\n"));
        assert!(
            body.contains(
                "Content-Disposition: form-data; name=\"file\"; filename=\"clip.m4a\"\r\n"
            )
        );
        assert!(body.contains("Content-Type: audio/m4a\r\n\r\naudio-bytes\r\n"));
        assert!(body.contains(
            "Content-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-large-v3-turbo\r\n"
        ));
        assert!(body.ends_with("--Boundary-Test--\r\n"));
    }

    #[test]
    fn request_builder_rejects_missing_api_key() {
        let audio = AudioCapture::new("clip.m4a", "audio/m4a", b"bytes".to_vec(), None);
        let options = GroqRequestOptions::new("   ");

        let error =
            build_groq_transcription_request(&audio, &options, "Boundary-Test").unwrap_err();

        assert_eq!(error, GroqRequestError::MissingApiKey);
    }

    #[test]
    fn request_builder_rejects_oversized_audio() {
        let audio = AudioCapture::new(
            "clip.wav",
            "audio/wav",
            vec![0u8; GROQ_MAX_UPLOAD_BYTES],
            None,
        );
        let options = GroqRequestOptions::new("secret-key");

        let error =
            build_groq_transcription_request(&audio, &options, "Boundary-Test").unwrap_err();

        assert!(matches!(
            error,
            GroqRequestError::AudioTooLarge {
                request_bytes,
                max_bytes: GROQ_MAX_UPLOAD_BYTES,
            } if request_bytes > GROQ_MAX_UPLOAD_BYTES
        ));
    }

    #[test]
    fn response_parser_extracts_text() {
        let text = parse_transcription_response(r#"{"text":" hello world "}"#).unwrap();
        assert_eq!(text, "hello world");
    }

    #[test]
    fn response_parser_rejects_missing_text() {
        let error = parse_transcription_response(r#"{"unexpected":"value"}"#).unwrap_err();
        assert_eq!(error, GroqRequestError::InvalidResponse);
    }
}
