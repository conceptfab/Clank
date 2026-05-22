"""Deploy page/ via FTPS to the host described in .env_ftp.

Modeled after the working ftplib.FTP_TLS pattern used in our other projects.

.env_ftp format (shell-style keys are preferred):
    FTP_HOST = host372606.hostido.net.pl
    FTP_USER = admin@example.com
    FTP_PASS = "password"
    FTP_DIR = "/public_html/clank"

Legacy Polish labels are also accepted:
    Logowanie:   <user>
    Hasło:       <password>
    Ścieżka:     <server-side absolute path; informational>

Optional extra lines:
    Host:        <ftp host>      # default: conceptfab.com
    Katalog:     <remote dir>    # default: / (login is usually chrooted)
    TLS:         on|off          # default: on (FTPS via AUTH TLS + prot_p)
    Passive:     on|off          # default: on

Usage:
    python3 scripts/deploy_page.py                # upload everything
    python3 scripts/deploy_page.py --dry-run      # show what would happen
    python3 scripts/deploy_page.py --skip-cleanup # don't delete existing files
"""

from __future__ import annotations

import argparse
import ftplib
import posixpath
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = PROJECT_ROOT / ".env_ftp"
LOCAL_DIR = PROJECT_ROOT / "page"

EXCLUDE_NAMES = {".DS_Store"}

# Items inside REMOTE_DIR that cleanup must not touch.
CLEANUP_PRESERVE_DIRS = {"cgi-bin", ".well-known", "logs"}
CLEANUP_PRESERVE_FILE_NAMES: set[str] = set()
CLEANUP_PRESERVE_FILE_SUFFIXES: tuple[str, ...] = ()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Deploy page/ via FTPS.")
    parser.add_argument("--dry-run", action="store_true", help="Show actions without uploading.")
    parser.add_argument(
        "--skip-cleanup",
        action="store_true",
        help="Don't remove existing remote files before upload.",
    )
    return parser.parse_args()


def parse_env_file(path: Path) -> dict[str, str]:
    if not path.exists():
        raise RuntimeError(f"Missing config file: {path}")

    aliases = {
        "logowanie": "user",
        "haslo": "password",
        "hasło": "password",
        "host": "host",
        "scieżka": "remote_path_info",
        "ścieżka": "remote_path_info",
        "sciezka": "remote_path_info",
        "katalog": "remote_dir",
        "tls": "tls",
        "passive": "passive",
        "ftp_host": "host",
        "ftp_user": "user",
        "ftp_pass": "password",
        "ftp_password": "password",
        "ftp_dir": "remote_dir",
    }

    config: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip("\r")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*|[^:=]+?)\s*[:=]\s*(.*)$", line)
        if not match:
            continue
        label = match.group(1).strip().lower()
        value = match.group(2).strip().strip("\"'")
        key = aliases.get(label)
        if key:
            config[key] = value
    return config


def to_bool(value: str | None, default: bool) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"on", "true", "1", "yes", "tak"}


def normalize_remote_root(value: str) -> str:
    clean = value.strip().replace("\\", "/")
    if not clean.startswith("/"):
        clean = "/" + clean
    return clean.rstrip("/") or "/"


def collect_local_files(base: Path) -> list[Path]:
    if not base.is_dir():
        raise RuntimeError(f"Missing source directory: {base}")
    files = [p for p in sorted(base.rglob("*")) if p.is_file() and p.name not in EXCLUDE_NAMES]
    if not files:
        raise RuntimeError(f"No files to upload in {base}")
    return files


def connect_ftp(host: str, user: str, password: str, *, use_tls: bool, passive: bool, timeout: int = 30) -> ftplib.FTP:
    cls = ftplib.FTP_TLS if use_tls else ftplib.FTP
    ftp = cls(host, timeout=timeout)
    ftp.login(user, password)
    ftp.set_pasv(passive)
    if use_tls and isinstance(ftp, ftplib.FTP_TLS):
        ftp.prot_p()
    return ftp


def ensure_remote_dir(ftp: ftplib.FTP, remote_dir: str) -> None:
    normalized = remote_dir.replace("\\", "/")
    if not normalized.startswith("/"):
        normalized = "/" + normalized
    current = ""
    for part in (p for p in normalized.split("/") if p):
        current = f"{current}/{part}"
        try:
            ftp.mkd(current)
        except ftplib.error_perm:
            pass


def list_remote_entries(ftp: ftplib.FTP, path: str) -> list[tuple[str, str]]:
    try:
        return [
            (name, facts.get("type", "file"))
            for name, facts in ftp.mlsd(path)
            if name not in (".", "..")
        ]
    except (ftplib.error_perm, AttributeError):
        pass

    try:
        raw = ftp.nlst(path)
    except ftplib.error_perm:
        return []

    results: list[tuple[str, str]] = []
    for entry in raw:
        name = posixpath.basename(entry.rstrip("/"))
        if name in ("", ".", ".."):
            continue
        full = posixpath.join(path, name)
        entry_type = "file"
        try:
            ftp.cwd(full)
            ftp.cwd(path)
            entry_type = "dir"
        except ftplib.error_perm:
            entry_type = "file"
        results.append((name, entry_type))
    return results


def should_preserve_file(name: str) -> bool:
    lower = name.lower()
    if lower in {n.lower() for n in CLEANUP_PRESERVE_FILE_NAMES}:
        return True
    return any(lower.endswith(s) for s in CLEANUP_PRESERVE_FILE_SUFFIXES)


def remove_remote_tree(ftp: ftplib.FTP, path: str, dry_run: bool) -> None:
    for name, entry_type in list_remote_entries(ftp, path):
        full = posixpath.join(path, name)
        if entry_type == "dir":
            remove_remote_tree(ftp, full, dry_run)
            print(f"RMDIR  {full}")
            if not dry_run:
                try:
                    ftp.rmd(full)
                except ftplib.error_perm as exc:
                    print(f"  (failed to remove directory: {exc})")
        else:
            if should_preserve_file(name):
                print(f"KEEP   {full}")
                continue
            print(f"DELETE {full}")
            if not dry_run:
                try:
                    ftp.delete(full)
                except ftplib.error_perm as exc:
                    print(f"  (failed to remove file: {exc})")


def cleanup_remote_root(ftp: ftplib.FTP, remote_root: str, preserve: set[str], dry_run: bool) -> None:
    label = ", ".join(sorted(preserve)) if preserve else "nothing"
    print(f"Cleaning {remote_root} (preserving: {label})")
    entries = list_remote_entries(ftp, remote_root)
    if not entries:
        print("  (directory is empty or unavailable)")
        return
    for name, entry_type in entries:
        if name in preserve:
            continue
        full = posixpath.join(remote_root, name)
        if entry_type == "dir":
            remove_remote_tree(ftp, full, dry_run)
            print(f"RMDIR  {full}")
            if not dry_run:
                try:
                    ftp.rmd(full)
                except ftplib.error_perm as exc:
                    print(f"  (failed to remove directory: {exc})")
        else:
            if should_preserve_file(name):
                print(f"KEEP   {full}")
                continue
            print(f"DELETE {full}")
            if not dry_run:
                try:
                    ftp.delete(full)
                except ftplib.error_perm as exc:
                    print(f"  (failed to remove file: {exc})")


def upload_file(ftp: ftplib.FTP, local_file: Path, remote_file: str, dry_run: bool) -> None:
    remote_dir = posixpath.dirname(remote_file)
    if not dry_run and remote_dir not in ("", "/"):
        ensure_remote_dir(ftp, remote_dir)
    print(f"UPLOAD {local_file.relative_to(PROJECT_ROOT)} -> {remote_file}")
    if dry_run:
        return
    with local_file.open("rb") as handle:
        ftp.storbinary(f"STOR {remote_file}", handle)


def main() -> None:
    args = parse_args()

    cfg = parse_env_file(ENV_FILE)
    user = cfg.get("user", "").strip()
    password = cfg.get("password", "")
    host = cfg.get("host", "").strip() or "conceptfab.com"
    remote_root = normalize_remote_root(cfg.get("remote_dir", "") or "/")
    use_tls = to_bool(cfg.get("tls"), default=True)
    passive = to_bool(cfg.get("passive"), default=True)

    if not user or not password:
        raise RuntimeError("Missing FTP_USER/FTP_PASS (or Logowanie:/Hasło:) in .env_ftp.")

    files = collect_local_files(LOCAL_DIR)

    print(f"FTP host:     {host}  (TLS={'on' if use_tls else 'off'}, passive={'on' if passive else 'off'})")
    print(f"User:         {user}")
    print(f"Remote root:  {remote_root}")
    print(f"Local dir:    {LOCAL_DIR}")
    print(f"Files:        {len(files)}")
    if args.dry_run:
        print("(dry run - no upload)")
    print()

    ftp = connect_ftp(host, user, password, use_tls=use_tls, passive=passive)
    try:
        if not args.dry_run:
            ensure_remote_dir(ftp, remote_root)

        if not args.skip_cleanup:
            cleanup_remote_root(ftp, remote_root, CLEANUP_PRESERVE_DIRS, args.dry_run)
        else:
            print("Skipping cleanup (--skip-cleanup).")

        count = 0
        for local_file in files:
            rel = local_file.relative_to(LOCAL_DIR).as_posix()
            remote_file = posixpath.join(remote_root, rel) if remote_root != "/" else "/" + rel
            upload_file(ftp, local_file, remote_file, args.dry_run)
            count += 1

        print()
        print(f"OK. Uploaded: {count} files.")
    finally:
        try:
            ftp.quit()
        except Exception:
            ftp.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"DEPLOY FAILED: {exc}")
        sys.exit(1)
