use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Config {
    pub groq_api_key: String,
}

impl Config {
    pub fn is_configured(&self) -> bool {
        !self.groq_api_key.trim().is_empty()
    }
}

pub fn resolve_config_path(
    environment: &[(impl AsRef<str>, impl AsRef<str>)],
    home_dir: &Path,
) -> PathBuf {
    if let Some(override_path) = env_value(environment, "VOICETOTEXT_CONFIG_PATH") {
        return expand_home(&override_path, home_dir);
    }

    let base_dir = env_value(environment, "XDG_CONFIG_HOME")
        .map(|value| expand_home(&value, home_dir))
        .unwrap_or_else(|| home_dir.join(".config"));

    base_dir.join("voicetotext").join("config.json")
}

pub fn resolve_api_key(
    environment: &[(impl AsRef<str>, impl AsRef<str>)],
    config_json: Option<&str>,
) -> Option<String> {
    if let Some(env_key) = env_value(environment, "GROQ_API_KEY") {
        let trimmed = env_key.trim();
        if !trimmed.is_empty() {
            return Some(trimmed.to_string());
        }
    }

    parse_api_key_from_config(config_json?).filter(|value| !value.trim().is_empty())
}

pub fn parse_api_key_from_config(config_json: &str) -> Option<String> {
    let parsed: serde_json::Value = serde_json::from_str(config_json).ok()?;
    for key in ["groq_api_key", "GROQ_API_KEY"] {
        if let Some(value) = parsed.get(key).and_then(|item| item.as_str()) {
            let trimmed = value.trim();
            if !trimmed.is_empty() {
                return Some(trimmed.to_string());
            }
        }
    }

    None
}

fn env_value(environment: &[(impl AsRef<str>, impl AsRef<str>)], key: &str) -> Option<String> {
    environment
        .iter()
        .find(|(candidate, _)| candidate.as_ref() == key)
        .map(|(_, value)| value.as_ref().to_string())
}

fn expand_home(path: &str, home_dir: &Path) -> PathBuf {
    if path == "~" {
        return home_dir.to_path_buf();
    }

    if let Some(stripped) = path.strip_prefix("~/") {
        return home_dir.join(stripped);
    }

    PathBuf::from(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn environment_api_key_wins_over_config_file() {
        let environment = [
            ("GROQ_API_KEY", "env-key"),
            ("XDG_CONFIG_HOME", "/tmp/config"),
        ];
        let config = r#"{"groq_api_key":"file-key"}"#;

        let key = resolve_api_key(&environment, Some(config));

        assert_eq!(key.as_deref(), Some("env-key"));
    }

    #[test]
    fn config_parser_accepts_both_supported_key_names() {
        assert_eq!(
            parse_api_key_from_config(r#"{"groq_api_key":"abc"}"#).as_deref(),
            Some("abc")
        );
        assert_eq!(
            parse_api_key_from_config(r#"{"GROQ_API_KEY":"xyz"}"#).as_deref(),
            Some("xyz")
        );
    }

    #[test]
    fn override_config_path_wins() {
        let environment = [("VOICETOTEXT_CONFIG_PATH", "~/custom/config.json")];
        let path = resolve_config_path(&environment, Path::new("/home/tester"));

        assert_eq!(path, PathBuf::from("/home/tester/custom/config.json"));
    }

    #[test]
    fn xdg_config_path_is_used_when_present() {
        let environment = [("XDG_CONFIG_HOME", "/home/tester/.config-alt")];
        let path = resolve_config_path(&environment, Path::new("/home/tester"));

        assert_eq!(
            path,
            PathBuf::from("/home/tester/.config-alt/voicetotext/config.json")
        );
    }

    #[test]
    fn default_config_path_falls_back_to_dot_config() {
        let environment: [(&str, &str); 0] = [];
        let path = resolve_config_path(&environment, Path::new("/home/tester"));

        assert_eq!(
            path,
            PathBuf::from("/home/tester/.config/voicetotext/config.json")
        );
    }
}
