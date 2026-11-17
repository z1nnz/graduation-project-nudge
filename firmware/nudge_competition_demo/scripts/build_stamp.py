Import("env")
import subprocess

revision = subprocess.check_output(
    ["git", "rev-parse", "--short=12", "HEAD"], cwd=env["PROJECT_DIR"], text=True
).strip()
dirty = subprocess.check_output(
    ["git", "status", "--porcelain", "--", "firmware/nudge_competition_demo"],
    cwd=env.subst("$PROJECT_DIR") + "/../..", text=True
).strip()
env.Append(CPPDEFINES=[("NUDGE_BUILD_ID", env.StringifyMacro(revision + ("-dirty" if dirty else "")))])
