"""Capture the actual camera sheet with fixture.patch temporarily applied."""
import json
import pathlib
import subprocess
import sys

driver, phase = sys.argv[1:3]
root = pathlib.Path(__file__).parent / phase
root.mkdir(exist_ok=True)
measurements = []


def run(*args):
    return subprocess.check_output([driver, *args], text=True)


for kind in (sys.argv[3].split(",") if len(sys.argv) > 3 else ["barcode", "label"]):
    for amount in ([float(x) for x in sys.argv[4].split(",")] if len(sys.argv) > 4 else [1, 1.25, 1.5, 1.75, 2, 0.25, 10, 20]):
        run("open", "juan-test.cal-macro-tracker", "--relaunch",
            "--launch-args=-CameraLayoutFixture", f"--launch-args={kind}",
            "--launch-args=-CameraLayoutServings", f"--launch-args={amount}")
        run("open", "juan-test.cal-macro-tracker", "calmacrotracker://add-food/scan-label")
        run("snapshot", "-i")
        run("snapshot", "--json")
        nodes = json.loads(run("snapshot", "--json"))["data"]["nodes"]
        card = next(n for n in nodes if n.get("kind") == "scroll-area")
        button = next(n for n in nodes if n.get("label") == ("Retake" if kind == "label" else "Scan again")
                      and n.get("kind") == "button")
        # Some XCTest snapshots include the top safe area in the ScrollView's frame.
        card_bottom = card["rect"]["y"] + card["rect"]["height"]
        height = card_bottom - 47
        stem = f"{kind}-{amount:g}"
        (root / f"{stem}.json").write_text(json.dumps(nodes, indent=2) + "\n")
        run("screenshot", str(root / f"{stem}.png"))
        measurements.append({"kind": kind, "servings": amount, "card_height": round(height, 3),
                             "button_y": round(button["rect"]["y"], 3)})
        (root / "sheet-heights.json").write_text(json.dumps(measurements, indent=2) + "\n")
print(json.dumps(measurements, indent=2))
