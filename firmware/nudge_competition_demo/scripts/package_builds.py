"""Package compiled output and its hash; never certify a connected device."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

project = Path(__file__).resolve().parents[1]
repo = project.parents[1]
output = project / "build" / "artifacts"
output.mkdir(parents=True, exist_ok=True)
environments = ["orbit_p0a", "orbit_demo", "orbit_static", "orbit_colors", "orbit_calibration", "station_demo"]
revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
source_tree = subprocess.check_output(
    ["git", "rev-parse", "HEAD:firmware/nudge_competition_demo"], cwd=repo, text=True
).strip()
dirty = bool(subprocess.check_output(
    ["git", "status", "--porcelain", "--", "firmware/nudge_competition_demo"], cwd=repo, text=True
).strip())
entries = []
for environment in environments:
    binary = project / ".pio" / "build" / environment / "firmware.bin"
    name = ("station_diagnostic_only" if environment == "station_demo" else environment) + ".bin"
    body = binary.read_bytes()  # Fail if ANY expected build is missing.
    # The embedded build identity must agree with this exact clean source commit.
    identity = revision[:12] + ("-dirty" if dirty else "")
    if identity.encode() not in body:
        raise RuntimeError("stale firmware build identity: " + environment)
    shutil.copyfile(binary, output / name)
    entries.append({"environment": environment, "file": name,
                    "bytes": len(body), "sha256": hashlib.sha256(body).hexdigest(),
                    "display_driver_configured": environment != "station_demo",
                    "physical_verified": False})
manifest = {"source_commit": revision, "source_tree": source_tree, "source_dirty": dirty,
            "build_identity": identity, "physical_verified": False,
            "station_lcd_implemented": False, "artifacts": entries}
(output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
shutil.copyfile(project / "README.md", output / "README.md")
print(json.dumps(manifest, indent=2))
