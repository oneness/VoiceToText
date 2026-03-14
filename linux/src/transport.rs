use reqwest::blocking::Client;

use crate::HttpRequest;

#[derive(Debug)]
pub enum TransportError {
    Request(reqwest::Error),
    HttpStatus { status: u16, body: String },
}

impl std::fmt::Display for TransportError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Request(error) => write!(f, "{error}"),
            Self::HttpStatus { status, body } => {
                write!(f, "HTTP {status} from Groq: {}", body.trim())
            }
        }
    }
}

impl std::error::Error for TransportError {}

pub fn execute_http_request(request: HttpRequest) -> Result<String, TransportError> {
    let client = Client::new();
    let mut builder = client.post(&request.url);

    for (key, value) in &request.headers {
        builder = builder.header(key, value);
    }

    let response = builder
        .body(request.body)
        .send()
        .map_err(TransportError::Request)?;

    let status = response.status();
    let body = response.text().map_err(TransportError::Request)?;

    if !status.is_success() {
        return Err(TransportError::HttpStatus {
            status: status.as_u16(),
            body,
        });
    }

    Ok(body)
}
