"""Fix-round E2E on the exclusively locked iPad, driven only by T3's bound CLI.

iOS 27's compatibility window reports app-local raw coordinates. The CLI's
coordinate dispatch also subtracts the observed 232 pt window origin, so app
controls need 2 * 232 added to x. Full-screen Settings uses ordinary selectors.
Screenshots and raw trees are retained, not reconstructed from these offsets.
"""
import contextlib
import json
import os
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parent
DRIVER = os.environ["MACROS_DEVICE_DRIVER"]
APP = "juan-test.cal-macro-tracker"
EVENTS = []


def run(*args):
    result = subprocess.run([DRIVER, *map(str, args)], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


def snapshot():
    return json.loads(run("snapshot", "--raw", "--json"))["data"]


def mark(event):
    EVENTS.append({"utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "event": event})
    print(event, flush=True)


def node(label, kind="button"):
    return next(n for n in snapshot()["nodes"]
                if n.get("kind") == kind and label in
                [n.get("label"), n.get("placeholder"), n.get("identifier")]
                and n["rect"]["height"] > 0 and 0 <= n["rect"]["y"] < 1160)


def press(label, kind="button"):
    n = node(label, kind)
    r = n["rect"]
    run("press", r["x"] + r["width"] / 2 + 464, r["y"] + r["height"] / 2,
        "--settle", "--settle-quiet", "1200")
    mark("press " + label)


def fill(label, value):
    n = node(label, "text-field")
    r = n["rect"]
    run("press", r["x"] + r["width"] - 2 + 464, r["y"] + r["height"] / 2)
    focused = next(n for n in snapshot()["nodes"] if n.get("focused") and n.get("kind") == "text-field")
    # Native fill cannot clear this window's offset input reliably. Focused type
    # avoids a second coordinate dispatch; inspect the exact value before/after.
    run("type", "\b" * len(focused.get("value", "")))
    run("type", value)
    actual = next(n for n in snapshot()["nodes"] if n.get("focused") and n.get("kind") == "text-field")
    assert actual.get("value") == value, actual
    mark("fill " + label + "=" + value)


def cap(name):
    run("screenshot", ROOT / "green" / (name + ".png"))
    data = snapshot()
    (ROOT / "green" / (name + ".json")).write_text(json.dumps(data, separators=(",", ":")) + "\n")
    if name not in ["keyboard", "landscape", "ax5"]:
        path = ROOT / "green" / (name + ".png")
        cropped = path.with_name(name + "-crop.png")
        subprocess.run(["ffmpeg", "-y", "-i", str(path), "-vf", "crop=410:1180:232:0",
                        "-frames:v", "1", str(cropped)], capture_output=True, check=True)
        cropped.replace(path)
    mark("capture " + name)
    return data


def launch(mode="barcode"):
    run("open", APP, "--relaunch", "--launch-args=-hasCompletedGoalSetup", "--launch-args=YES",
        "--launch-args=-hasCompletedDashboardTutorial", "--launch-args=YES",
        "--launch-args=-CameraLayoutFixture", "--launch-args=" + mode)
    press("Camera")
    mark("launch " + mode)


@contextlib.contextmanager
def record(name):
    raw = pathlib.Path("/tmp") / ("macros-morph3-" + name + "-" + str(time.time_ns()) + ".mp4")
    run("record", "start", raw, "--scope", "device", "--hide-touches")
    mark("record " + str(raw))
    try:
        yield
    finally:
        run("record", "stop")
        subprocess.run(["ffmpeg", "-y", "-i", str(raw), "-vf",
                        "fps=60,scale=820:1180,crop=410:1180:232:0,scale=390:-2",
                        "-c:v", "libx264", "-crf", "26", "-an", str(ROOT / "green" / (name + ".mp4"))],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)


def morph():
    launch()
    # Compare the same retained, unedited session on both sides of the cycle.
    press("Details")
    press("Show less")
    cap("compact")
    before = {label: node(label)["rect"] for label in ["Details", "Log"]}
    with record("morph"):
        press("Details")
        cap("expanded")
        press("Show less")
        cap("collapsed")
    after = {label: node(label)["rect"] for label in ["Details", "Log"]}
    assert before == after, (before, after)
    (ROOT / "green" / "compact-row-bounds.json").write_text(
        json.dumps({"before": before, "after": after}, indent=2) + "\n")
    press("Details")
    # Fling only the retained Form, below the persistent summary and above Log.
    # Gestures validate against the physical x=232...642 window before the same
    # offset correction. x=620 lands inside the Form and passes that validation.
    run("swipe", 620, 700, 620, 400, "--count", 6, "--pause-ms", 150)
    data = cap("expanded-bottom")
    toggle = next(n for n in data["nodes"] if n.get("kind") == "switch" and n.get("label") == "Save as reusable food")
    log = node("Log")
    assert toggle["rect"]["y"] + toggle["rect"]["height"] < log["rect"]["y"], (toggle, log)
    # XCTest's window-offset hittable flag is unreliable; prove actual input works.
    r = toggle["rect"]
    run("press", r["x"] + r["width"] - 24 + 464, r["y"] + r["height"] / 2, "--settle")
    assert not node("Save as reusable food", "switch").get("checked")
    run("press", r["x"] + r["width"] - 24 + 464, r["y"] + r["height"] / 2, "--settle")
    assert node("Save as reusable food", "switch").get("checked")


def edited():
    launch()
    press("Details")
    fill("Name", "Morph3 Edited Tortilla")
    for _ in range(4):
        press("Next field")
    fill("Calories", "200")
    cap("keyboard")
    press("Done")
    press("Show less")
    data = cap("edited-compact")
    assert any(n.get("label") == "200 kcal" for n in data["nodes"])
    press("Log")
    data = cap("edited-logged")
    assert any(n.get("label") == "Logged" for n in data["nodes"])
    press("Close camera")
    data = cap("edited-dashboard")
    assert any("Morph3 Edited Tortilla" in n.get("label", "") and "200 calories" in n.get("label", "")
               for n in data["nodes"])


def grams():
    launch()
    press("Details")
    press("Grams")
    press("Grams, 37 g, Increment")
    cap("grams-expanded")
    press("Show less")
    data = cap("grams-compact")
    assert any(n.get("label") == "Grams, 42 g" for n in data["nodes"])
    press("Details")
    data = cap("grams-restored")
    assert any(n.get("label") == "Grams" and n.get("selected") for n in data["nodes"])
    assert any("42 g" in n.get("label", "") for n in data["nodes"])
    press("Show less")
    press("Scan again")
    cap("dirty-collapsed-scan")
    press("Keep Editing")
    press("Log")
    press("Close camera")
    data = cap("grams-dashboard")
    assert any("42 g" in n.get("label", "") for n in data["nodes"])


def layout():
    launch()
    press("Details")
    run("orientation", "landscape-left")
    cap("landscape")
    run("orientation", "portrait")
    run("settings", "text-size", "accessibility-extra-extra-extra-large")
    launch()
    press("Details")
    data = cap("ax5")
    less = node("Show less")
    title = next(n for n in data["nodes"] if n.get("kind") == "text" and n.get("label") == "Fajita Flour Tortillas")
    assert less["rect"]["y"] + less["rect"]["height"] < title["rect"]["y"], (less, title)
    press("Show less")
    assert node("Details")
    run("settings", "text-size", "large")


def reduced():
    launch()
    cap("reduce-motion-compact")
    with record("reduce-motion"):
        press("Details")
        cap("reduce-motion-expanded")
        press("Show less")
        cap("reduce-motion-collapsed")


def motion_on():
    system_motion(True)


def motion_off():
    system_motion(False)


def system_motion(enabled):
    run("open", "com.apple.Preferences")
    if not any(n.get("label") == "Reduce Motion" for n in snapshot()["nodes"]):
        run("press", 'label="Accessibility" role=button', "--settle")
        run("press", 'label="Motion"', "--settle")
    current = node("Reduce Motion", "switch")
    if bool(current.get("checked")) != enabled:
        r = current["rect"]
        run("press", r["x"] + r["width"] - 28, r["y"] + r["height"] / 2, "--settle")
    assert bool(node("Reduce Motion", "switch").get("checked")) == enabled
    name = "reduce-motion-setting-" + ("on" if enabled else "restored")
    run("screenshot", ROOT / "green" / (name + ".png"))
    (ROOT / "green" / (name + ".json")).write_text(json.dumps(snapshot(), separators=(",", ":")) + "\n")
    mark(name)


if __name__ == "__main__":
    import sys
    scenario = sys.argv[1]
    try:
        globals()[scenario]()
        mark("PASS " + scenario)
    finally:
        (ROOT / "green" / (scenario + "-events.json")).write_text(json.dumps(EVENTS, indent=2) + "\n")
