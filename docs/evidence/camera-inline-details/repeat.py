"""Repeat core E2E against an installed fixture build, only on an exclusively owned device."""
import os

if not os.environ.get("MACROS_DEVICE_DRIVER"):
    raise SystemExit("Set MACROS_DEVICE_DRIVER to the absolute T3 bound driver after acquiring its simulator lock.")

from driver import APP, capture, fill, press, run, snapshot, toggle


def launch(mode):
    run("open", APP, "--relaunch", "--launch-args=-hasCompletedGoalSetup", "--launch-args=YES",
        "--launch-args=-hasCompletedDashboardTutorial", "--launch-args=YES",
        "--launch-args=-CameraLayoutFixture", "--launch-args=" + mode)
    press("Camera")


def check(label, enabled=None):
    matches = [n for n in snapshot()["nodes"] if n.get("label") == label]
    assert matches, label
    if enabled is not None:
        assert any(n.get("enabled") == enabled for n in matches), (label, enabled)


launch("barcode")
press("Details")
capture("rerun", "expanded")
run("gesture", "pan", "190", "500", "0", "-180", "700")
fill("Calories", "200")
capture("rerun", "keyboard")
press("Next field")
data = capture("rerun", "next-protein")
assert any(n.get("label") == "Protein" and n.get("focused") for n in data["nodes"])
press("Previous field")
data = capture("rerun", "previous-calories")
assert any(n.get("label") == "Calories" and n.get("focused") for n in data["nodes"])
press("Done")
press("Log")
check("Logged")
capture("rerun", "logged")
press("Scan again")
run("wait", "text", "Camera unavailable. Choose a photo to scan a barcode or nutrition label.", "10000")
capture("rerun", "scan-again")
press("Close camera")

launch("barcode")
press("Details")
fill("Name", "Preserved E2E Draft")
press("Done")
press("Scan again")
check("Keep Editing")
capture("rerun", "dirty-dialog")
press("Keep Editing")
run("gesture", "pan", "195", "70", "0", "650", "900")
run("wait", "text", "Food details", "10000")
capture("rerun", "dirty-swipe-blocked")
press("Close camera")
press("Discard Changes")
run("wait", "absent", 'label="Food details"', "10000")

launch("label-missing")
press("Edit details")
check("Log", False)
for _ in range(5):
    run("gesture", "pan", "190", "500", "0", "-190", "700")
toggle("Calories is intentionally 0")
check("Log", False)
toggle("Protein is intentionally 0")
check("Log", True)
capture("rerun", "review-confirmed")
press("Log")
check("Logged")
press("Close camera")

launch("recovery")
press("Enter manually")
check("Log", False)
fill("Name", "Recovered E2E Food")
press("Done")
check("Log", True)
press("Log")
check("Logged")
capture("rerun", "recovery-logged")
press("Close camera")
print("Core inline camera E2E passed. Restore the clean app, close the session and release only your lock.")
