"""Emit a regular Messages attachment. Never follow symlinks below the attachment directory."""
import json
import os
from pathlib import Path
import stat
import sys

def main():
    root = Path.home() / "Library/Messages/Attachments"
    parts = Path(json.load(sys.stdin)).expanduser().relative_to(root).parts
    if not parts or ".." in parts:
        raise ValueError("Use original_path under ~/Library/Messages/Attachments")
    directory = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    fd = os.open(root, directory)
    try:
        for name in parts[:-1]:
            child = os.open(name, directory, dir_fd=fd)
            os.close(fd)
            fd = child
        flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK
        with os.fdopen(os.open(parts[-1], flags, dir_fd=fd), "rb") as fp:
            before = os.fstat(fp.fileno())
            if not stat.S_ISREG(before.st_mode) or before.st_size > 64 * 1024 * 1024:
                raise ValueError("Expected a regular attachment up to 64 MiB")
            remaining = before.st_size
            while remaining:
                chunk = fp.read(min(65536, remaining))
                if not chunk:
                    raise ValueError("Attachment changed while copying")
                remaining -= len(chunk)
                sys.stdout.buffer.write(chunk)
            after = os.fstat(fp.fileno())
            if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
                raise ValueError("Attachment changed while copying")
    finally:
        os.close(fd)

if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        sys.exit(str(error))
