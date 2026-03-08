pub fn journal_file_name(date_stamp: &str) -> String {
    format!("{date_stamp}.md")
}

pub fn render_journal_entry(
    existing_content: Option<&str>,
    header_date: &str,
    time_stamp: &str,
    text: &str,
) -> String {
    let mut output = String::new();

    if let Some(existing) = existing_content {
        output.push_str(existing);
    } else {
        output.push_str("# Transcriptions - ");
        output.push_str(header_date);
        output.push_str("\n\n");
    }

    output.push_str("## ");
    output.push_str(time_stamp);
    output.push_str("\n\n");
    output.push_str(text);
    output.push_str("\n\n---\n\n");

    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn journal_file_name_matches_existing_repo_convention() {
        assert_eq!(journal_file_name("2026-03-07"), "2026-03-07.md");
    }

    #[test]
    fn new_journal_entry_matches_macos_markdown_format() {
        let rendered = render_journal_entry(None, "March 7, 2026", "9:41 AM", "Transcribed text");

        assert_eq!(
            rendered,
            "# Transcriptions - March 7, 2026\n\n## 9:41 AM\n\nTranscribed text\n\n---\n\n"
        );
    }

    #[test]
    fn existing_journal_content_is_appended_without_rewriting_header() {
        let existing = "# Transcriptions - March 7, 2026\n\n## 9:00 AM\n\nEarlier text\n\n---\n\n";
        let rendered =
            render_journal_entry(Some(existing), "March 7, 2026", "9:41 AM", "Later text");

        assert_eq!(
            rendered,
            "# Transcriptions - March 7, 2026\n\n## 9:00 AM\n\nEarlier text\n\n---\n\n## 9:41 AM\n\nLater text\n\n---\n\n"
        );
    }
}
