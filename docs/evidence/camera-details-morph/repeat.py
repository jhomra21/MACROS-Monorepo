"""Real-app E2E. Requires the evidence fixture build and an exclusively locked simulator."""
import argparse
import contextlib
import json
import os
import pathlib
import signal
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent / "camera-inline-details"))
if not os.environ.get("MACROS_DEVICE_DRIVER"):
    raise SystemExit("Set MACROS_DEVICE_DRIVER to the T3 device_open bound executable.")
import driver

driver.ROOT = ROOT
from driver import APP, capture, fill, press, run, snapshot, toggle

original_press = press
original_fill = fill


def fill(name, value):
    try:
        return original_fill(name, value)
    except RuntimeError as error:
        if "TEXT_INPUT_" not in str(error):
            raise
        data = snapshot()
        node = next(n for n in data["nodes"] if n.get("kind") == "text-field" and n.get("focused"))
        if node.get("value") == value:
            mark("input already committed: " + name)
            return
        mark("observed input retry: " + name + " value=" + str(node.get("value")))
        return run("fill", "@" + node["ref"] + "~s" + str(data["refsGeneration"]), value,
                   "--delay-ms", "80", "--settle")


def press(name, kind="button"):
    if name in ["Details", "Edit details", "Show less"]:
        run("snapshot", "-i")
        return run("press", 'id="camera-details-toggle"', "--settle")
    if name == "Log":
        run("snapshot", "-i")
        return run("press", 'id="camera-log"', "--settle")
    return original_press(name, kind)

UDID = "F976E800-DA1F-4F20-B755-DFD964E33975"
EVENTS = []


def mark(event):
    item = {"utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "event": event}
    EVENTS.append(item)
    print(json.dumps(item), flush=True)


def check(label, enabled=None):
    nodes = [n for n in snapshot()["nodes"] if n.get("label") == label
             and (n.get("hittable") or enabled is False and n.get("enabled") is False)]
    assert nodes, label
    if enabled is not None:
        assert any(n.get("enabled") == enabled for n in nodes), (label, enabled)


def launch(mode="barcode"):
    run("open", APP, "--relaunch", "--launch-args=-hasCompletedGoalSetup", "--launch-args=YES",
        "--launch-args=-hasCompletedDashboardTutorial", "--launch-args=YES",
        "--launch-args=-CameraLayoutFixture", "--launch-args=" + mode)
    press("Camera")
    mark("launch " + mode)


def cap(name):
    mark(name)
    return capture("green", name)


@contextlib.contextmanager
def record(name):
    raw = pathlib.Path("/tmp/macros-morph-" + name + "-" + str(time.time_ns()) + ".mp4")
    process = subprocess.Popen(["xcrun", "simctl", "io", UDID, "recordVideo", "--codec=h264", str(raw)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    while True:
        line = process.stderr.readline()
        assert line, "recordVideo ended before its first frame"
        if b"Recording started" in line:
            break
    mark("record " + name)
    mark("raw " + str(raw))
    try:
        yield
    finally:
        process.send_signal(signal.SIGINT)
        process.communicate(timeout=30)
        assert process.returncode == 0, "simctl recording failed"
        subprocess.run(["ffmpeg", "-y", "-i", str(raw), "-vf", "scale=390:-2", "-c:v", "libx264",
                        "-crf", "30", "-preset", "fast", "-an", str(ROOT / "green" / (name + ".mp4"))],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)


def morph():
    launch()
    cap("compact")
    with record("morph"):
        press("Details")
        cap("expanded")
        check("Show less")
        press("Show less")
        cap("collapsed")
        check("Details")


def edited():
    launch()
    press("Details")
    fill("Name", "Morph Edited Tortilla")
    for _ in range(4):
        press("Next field")
    fill("Calories", "200")
    cap("keyboard")
    press("Done")
    with record("edited-log"):
        press("Show less")
        data = cap("edited-compact")
        assert any("Morph Edited Tortilla" in n.get("label", "") for n in data["nodes"])
        check("200 kcal")
        press("Log")
        check("Logged")
        cap("edited-logged")
        press("Close camera")
        data = cap("edited-dashboard")
        assert any("Morph Edited Tortilla" in n.get("label", "") and "200 calories" in n.get("label", "")
                   for n in data["nodes"])


def grams():
    launch()
    press("Details")
    fill("Name", "Morph Grams Tortilla")
    press("Done")
    press("Grams")
    press("Grams, 37 g, Increment")
    cap("grams-expanded")
    with record("grams-retained"):
        press("Show less")
        cap("grams-compact")
        press("Details")
        data = cap("grams-restored")
        assert any(n.get("label") == "Grams" and n.get("selected") for n in data["nodes"])
        assert any("42 g" in n.get("label", "") for n in data["nodes"])
        press("Show less")
        press("Scan again")
        check("Keep Editing")
        cap("dirty-collapsed-scan")
        press("Keep Editing")
        press("Close camera")
        check("Keep Editing")
        cap("dirty-collapsed-close")
        press("Keep Editing")
        run("gesture", "pan", "195", "70", "0", "650", "900")
        check("Details")
        cap("dirty-collapsed-swipe-blocked")
        press("Log")
        check("Logged")
        press("Close camera")
        data = cap("grams-dashboard")
        assert any("Morph Grams Tortilla" in n.get("label", "") and "42 g" in n.get("label", "")
                   for n in data["nodes"])


def servings():
    launch()
    press("Details")
    fill("Name", "Morph Servings Tortilla")
    press("Done")
    press("Servings, Increment")
    press("Show less")
    cap("servings-compact")
    check("200 kcal")
    press("Details")
    cap("servings-restored")
    press("Show less")
    press("Log")
    check("Logged")
    press("Close camera")
    data = cap("servings-dashboard")
    assert any("Morph Servings Tortilla" in n.get("label", "") and "1.25 ×" in n.get("label", "")
               and "200 calories" in n.get("label", "") for n in data["nodes"])


def review():
    launch("label-missing")
    press("Edit details")
    check("Show less")
    check("Log", False)
    cap("review-initial-disabled")
    for _ in range(5):
        run("gesture", "pan", "190", "500", "0", "-190", "700")
    toggle("Calories is intentionally 0")
    run("gesture", "pan", "190", "480", "0", "-100", "700")
    toggle("Protein is intentionally 0")
    run("gesture", "pan", "190", "480", "0", "-120", "700")
    toggle("Save as reusable food")
    with record("review-retained"):
        cap("review-confirmed")
        press("Show less")
        cap("review-compact")
        press("Edit details")
        data = cap("review-restored")
        assert any(n.get("label") == "Protein is intentionally 0" and n.get("value") == "1"
                   for n in data["nodes"])
        assert any(n.get("label") == "Save as reusable food" and n.get("value") == "0"
                   for n in data["nodes"])
        check("Log", True)
        run("gesture", "pan", "190", "450", "0", "100", "700")
        data = cap("review-confirmations-restored")
        assert any(n.get("label") == "Calories is intentionally 0" and n.get("value") == "1"
                   for n in data["nodes"])
        press("Show less")
        press("Retake")
        check("Keep Editing")
        cap("dirty-collapsed-retake")
        press("Keep Editing")
        press("Log")
        check("Logged")
        cap("review-logged")


def unfinished():
    launch()
    press("Details")
    fill("Name", "Unfinished Morph Tortilla")
    for _ in range(4):
        press("Next field")
    fill("Calories", "1.")
    cap("unfinished-focused")
    press("Done")
    run("gesture", "pan", "190", "480", "0", "-160", "700")
    cap("unfinished-before")
    press("Show less")
    press("Details")
    run("gesture", "pan", "190", "480", "0", "-160", "700")
    data = cap("unfinished-restored")
    assert any(n.get("value") == "1." for n in data["nodes"] if n.get("kind") == "text-field")
    press("Grams")
    press("Grams, 37 g, Increment")
    data = cap("unfinished-quantity-changed")
    assert any(n.get("label") == "1.1 kcal" for n in data["nodes"])
    assert not any(n.get("value") == "1." for n in data["nodes"] if n.get("kind") == "text-field")


def layout():
    launch()
    press("Details")
    run("orientation", "landscape-left")
    cap("landscape")
    run("orientation", "portrait")
    run("settings", "text-size", "accessibility-extra-extra-extra-large")
    launch()
    press("Details")
    cap("ax5")
    run("settings", "text-size", "large")
    launch("recovery")
    press("Enter manually")
    cap("recovery")
    fill("Name", "Morph Recovery Food")
    press("Done")
    press("Show less")
    cap("recovery-compact")
    press("Log")
    check("Logged")


def reduced():
    launch()
    with record("reduce-motion"):
        press("Details")
        cap("reduce-motion-expanded")
        press("Show less")
        cap("reduce-motion-collapsed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("scenario", choices=["morph", "edited", "grams", "servings", "review", "unfinished", "layout", "reduced"])
    args = parser.parse_args()
    (ROOT / "green").mkdir(exist_ok=True)
    try:
        globals()[args.scenario]()
        mark("PASS " + args.scenario)
    finally:
        (ROOT / "green" / (args.scenario + "-events.json")).write_text(json.dumps(EVENTS, indent=2) + "\n")
