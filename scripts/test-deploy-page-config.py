#!/usr/bin/env python3
"""Tiny contract test for deploy_page.py config parsing."""

from __future__ import annotations

import tempfile
from pathlib import Path

import deploy_page


def test_shell_style_env_file_is_supported() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / ".env_ftp"
        path.write_text(
            "\n".join(
                [
                    "# FTP config",
                    "FTP_HOST = host372606.hostido.net.pl",
                    "FTP_USER = admin@example.com",
                    'FTP_PASS = "secret value"',
                    'FTP_DIR = "/public_html/clank"',
                ]
            ),
            encoding="utf-8",
        )

        cfg = deploy_page.parse_env_file(path)

    assert cfg["host"] == "host372606.hostido.net.pl"
    assert cfg["user"] == "admin@example.com"
    assert cfg["password"] == "secret value"
    assert cfg["remote_dir"] == "/public_html/clank"


if __name__ == "__main__":
    test_shell_style_env_file_is_supported()
    print("OK")
