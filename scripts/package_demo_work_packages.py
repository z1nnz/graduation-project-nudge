#!/usr/bin/env python3
"""Package the pinned Competition Demo Edition docs without old work packages."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

SOURCE = "9ace911bf892dfb3a451acce7e2ecbeb41904f7d"
ROOT = Path(__file__).resolve().parents[1]
PREFIX = "docs/work-packages/"


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: package_demo_work_packages.py OUTPUT.zip")
    paths = git("ls-tree", "-r", "--name-only", SOURCE, PREFIX).decode().splitlines()
    expected = {f"{i:02d}" for i in range(14)}
    if (len(paths) != 15 or any(not p.endswith(".md") for p in paths)
            or {Path(p).name[:2] for p in paths if Path(p).name != "README.md"} != expected):
        raise SystemExit("Source must contain README and exactly packages 00 through 13")
    payload = {"work-packages/" + p[len(PREFIX):]: git("show", f"{SOURCE}:{p}") for p in paths}
    if b"Competition Demo Edition v1" not in payload["work-packages/README.md"]:
        raise SystemExit("Refusing to package superseded product work packages")
    manifest = {
        "source_commit": SOURCE,
        "edition": "Competition Demo Edition v1",
        "files": [{"path": p, "sha256": hashlib.sha256(data).hexdigest()}
                  for p, data in sorted(payload.items())],
    }
    payload["MANIFEST.json"] = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode()
    payload["README.md"] = (
        "# Nudge 競賽 Demo 工作包 v1\n\n"
        "請先讀 [新版工作包](work-packages/README.md)、00、01、09、11。\n\n"
        "舊的 2026-11-04 ZIP 與 32 份產品工作包已 superseded，不作本次執行依據。\n"
        "P0-A 只有兩台各自離線 Home → Focus → Complete；不新增採購。\n"
        "本 ZIP 只有規劃文件，不包含 firmware binary 或實機驗收證據。\n"
    ).encode()
    payload["VERSION.txt"] = f"Edition: Competition Demo Edition v1\nSource: {SOURCE}\nDevice verified: no\n".encode()
    output = Path(sys.argv[1])
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path, data in sorted(payload.items()):
            entry = zipfile.ZipInfo(path, date_time=(2026, 11, 14, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, data)
    print(f"15 source Markdown files; SHA-256 {hashlib.sha256(output.read_bytes()).hexdigest()}")
    print(output)


if __name__ == "__main__":
    main()
