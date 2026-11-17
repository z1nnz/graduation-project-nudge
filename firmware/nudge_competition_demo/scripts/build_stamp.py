Import("env")
import subprocess
from pathlib import Path

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
env.Append(CPPDEFINES=[("NUDGE_BUILD_ID", env.StringifyMacro(revision + ("-dirty" if dirty else "")))])
