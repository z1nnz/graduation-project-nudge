"""Package compiled output and its hash; never certify a connected device."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

project = Path(__file__).resolve().parents[1]
repo = project.parents[1]
output = project / "build" / "artifacts"
environments = ["orbit_p0a", "orbit_demo", "orbit_static", "orbit_colors", "orbit_calibration", "orbit_p1_check",
                "station_p0a", "station_demo", "station_colors", "station_calibration", "station_p1_check"]
if (project / "include" / "local_hardware_profile.h").exists():
    raise RuntimeError("local hardware profile present: public packager requires the unconfigured default profile")
revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
source_tree = subprocess.check_output(
    ["git", "rev-parse", "HEAD:firmware/nudge_competition_demo"], cwd=repo, text=True
).strip()
dirty = bool(subprocess.check_output(
    ["git", "status", "--porcelain", "--", "firmware/nudge_competition_demo"], cwd=repo, text=True
).strip())
entries = []
binaries = []
for environment in environments:
    binary = project / ".pio" / "build" / environment / "firmware.bin"
    station = environment.startswith("station_")
    name = environment + ("_unconfigured" if station else "") + ".bin"
    body = binary.read_bytes()  # Fail if ANY expected build is missing.
    # The embedded build identity must agree with this exact clean source commit.
    identity = revision[:12] + ("-dirty" if dirty else "")
    if identity.encode() not in body:
        raise RuntimeError("stale firmware build identity: " + environment)
    binaries.append((name, body))
    entries.append({"environment": environment, "file": name,
                    "bytes": len(body), "sha256": hashlib.sha256(body).hexdigest(),
                    "display_driver_compiled": True, "pinmap_configured": not station,
                    "optional_drivers_compiled": environment.endswith("p1_check"),
                    "p1_armed": False,
                    "physical_verified": False})
manifest = {"source_commit": revision, "source_tree": source_tree, "source_dirty": dirty,
            "build_identity": identity, "physical_verified": False,
            "station_lcd_adapter_implemented": True, "station_pinmap_configured": False,
            "p1_armed": False, "artifacts": entries}
if output.exists():
    shutil.rmtree(output)
output.mkdir(parents=True, exist_ok=True)
for name, body in binaries:
    (output / name).write_bytes(body)
(output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
shutil.copyfile(project / "README.md", output / "README.md")
print(json.dumps(manifest, indent=2))
