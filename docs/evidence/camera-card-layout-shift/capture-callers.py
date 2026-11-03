"""Capture real Add Food/dashboard screens after seeding a synthetic long-name food."""
import pathlib
import subprocess
import sys

driver, phase = sys.argv[1:3]
root = pathlib.Path(__file__).parent / phase


def run(*args):
    return subprocess.check_output([driver, *args], text=True)


for size in ["large", "accessibility-extra-large"]:
    run("settings", "text-size", size)
    run("open", "juan-test.cal-macro-tracker", "--relaunch")
    run("snapshot", "-i")
    run("snapshot", "-i")
    if size != "large":
        run("scroll", "bottom", "--settle")
    suffix = "" if size == "large" else "-accessibility"
    run("screenshot", str(root / f"dashboard{suffix}.png"))
    run("open", "juan-test.cal-macro-tracker", "calmacrotracker://add-food")
    run("snapshot", "-i")
    run("snapshot", "-i")
    run("screenshot", str(root / f"add-food{suffix}.png"))
run("settings", "text-size", "large")
