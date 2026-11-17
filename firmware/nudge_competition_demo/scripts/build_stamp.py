Import("env")
import subprocess
from pathlib import Path
import hashlib

# Third-party assertions can embed __FILE__ in the binary. Keep operator paths
# out of deliverable images as well as out of the published build log.
env.Append(CCFLAGS=["-ffile-prefix-map=" + str(Path.home()) + "=operator-home"])

revision = subprocess.check_output(
    ["git", "rev-parse", "--short=12", "HEAD"], cwd=env["PROJECT_DIR"], text=True
).strip()
dirty = subprocess.check_output(
    ["git", "status", "--porcelain", "--", "firmware/nudge_competition_demo"],
    cwd=env.subst("$PROJECT_DIR") + "/../..", text=True
).strip()
profile = Path(env["PROJECT_DIR"]) / "include" / "local_hardware_profile.h"
profile_id = "-hw" + hashlib.sha256(profile.read_bytes()).hexdigest()[:8] if profile.exists() else ""
env.Append(CPPDEFINES=[("NUDGE_BUILD_ID", env.StringifyMacro(revision + ("-dirty" if dirty else "") + profile_id))])
