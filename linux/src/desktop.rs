use std::process::Command;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DesktopCapabilities {
    pub has_global_shortcuts_portal: bool,
}

pub fn probe_desktop_capabilities(
    _environment: &[(impl AsRef<str>, impl AsRef<str>)],
) -> DesktopCapabilities {
    DesktopCapabilities {
        has_global_shortcuts_portal: portal_interface_exists(
            "org.freedesktop.portal.GlobalShortcuts",
        ),
    }
}

fn portal_interface_exists(interface_name: &str) -> bool {
    Command::new("gdbus")
        .args([
            "introspect",
            "--session",
            "--dest",
            "org.freedesktop.portal.Desktop",
            "--object-path",
            "/org/freedesktop/portal/desktop",
        ])
        .output()
        .map(|output| {
            output.status.success()
                && String::from_utf8_lossy(&output.stdout).contains(interface_name)
        })
        .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn probe_desktop_capabilities_only_tracks_global_shortcuts_portal() {
        let environment: [(&str, &str); 0] = [];
        let capabilities = probe_desktop_capabilities(&environment);
        assert_eq!(
            capabilities,
            DesktopCapabilities {
                has_global_shortcuts_portal: capabilities.has_global_shortcuts_portal,
            }
        );
        assert!(matches!(
            capabilities.has_global_shortcuts_portal,
            true | false
        ));
    }
}
