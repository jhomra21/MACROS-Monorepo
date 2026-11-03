"""Evidence helpers. Run only against the exclusively locked iPhone 17e B."""
import json
import os
import pathlib
import subprocess
import sys

DRIVER = os.environ.get("MACROS_DEVICE_DRIVER", "/Users/juan/.t3/userdata/device/targets/t3-03490f972cbea41582b27d3a/agent-device")
APP = "juan-test.cal-macro-tracker"
ROOT = pathlib.Path(__file__).resolve().parent


def run(*args):
    result = subprocess.run([DRIVER, *map(str, args)], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


def snapshot():
    return json.loads(run("snapshot", "--json"))["data"]


def target(name, kind=None):
    data = snapshot()
    nodes = [n for n in data["nodes"] if (kind is None or n.get("kind") == kind)
             and name in [n.get("label"), n.get("placeholder"), n.get("value"), n.get("identifier")]]
    if not nodes:
        raise RuntimeError(f"Missing {name}: " + str([(n.get("kind"), n.get("label"), n.get("value")) for n in data["nodes"]]))
    return "@" + nodes[0]["ref"] + "~s" + str(data["refsGeneration"])


def press(name, kind="button"):
    run("snapshot", "-i")
    if kind == "button":
        return run("press", f"label={json.dumps(name)} role=button", "--settle")
    return run("press", target(name, kind), "--settle")


def fill(name, value):
    data = snapshot()
    node = next(n for n in data["nodes"] if n.get("kind") == "text-field"
                and name in [n.get("label"), n.get("placeholder"), n.get("value")])
    if node.get("label"):
        run("press", f"label={json.dumps(node['label'])} editable=true", "--settle")
        return run("fill", f"label={json.dumps(node['label'])} editable=true", value, "--settle")
    # XCTest's blank fields have a placeholder but no semantic label. Capture before coordinate input.
    run("screenshot", "/tmp/macros-inline-before-unlabelled-field.png")
    rect = node["rect"]
    run("press", rect["x"] + rect["width"] / 2, rect["y"] + rect["height"] / 2, "--settle")
    focused = next(n for n in snapshot()["nodes"] if n.get("kind") == "text-field" and n.get("focused"))
    return run("fill", "@" + focused["ref"], value, "--settle")


def toggle(name):
    data = snapshot()
    wrapper = next(n for n in data["nodes"] if n.get("label") == name and n.get("kind") == "switch")
    control = next(n for n in data["nodes"] if n.get("parentIndex") == wrapper["index"] and n.get("role") == "UISwitch")
    return run("press", "@" + control["ref"] + "~s" + str(data["refsGeneration"]), "--settle")


def capture(phase, name):
    folder = ROOT / phase
    folder.mkdir(parents=True, exist_ok=True)
    data = snapshot()
    (folder / f"{name}.json").write_text(json.dumps(data, indent=2) + "\n")
    run("screenshot", str(folder / f"{name}.png"))
    return data


if __name__ == "__main__":
    action, *args = sys.argv[1:]
    if action == "capture":
        capture(*args)
    elif action == "fill":
        print(fill(*args))
    elif action == "press":
        print(press(*args))
    elif action == "toggle":
        print(toggle(*args))
    else:
        print(run(action, *args))
