"""Real non-camera routes, identical inputs on main and the extraction."""
import sys
from driver import APP, capture, fill, press, run, snapshot, target

phase = sys.argv[1]


def open_search():
    run("open", APP, "calmacrotracker://add-food")
    if any(n.get("label") == "Enjoying MACROS?" for n in snapshot()["nodes"]):
        capture(phase, "rating-prompt-interruption")
        press("Not Now")
    run("wait", "text", "Search foods on device or online", "10000")
    return snapshot()


run("settings", "clear-app-state", APP)
run("open", APP, "--relaunch", "--launch-args=-hasCompletedGoalSetup", "--launch-args=YES",
    "--launch-args=-hasCompletedDashboardTutorial", "--launch-args=YES",
    "--launch-args=-commonFoodSeedVersion", "--launch-args=inline-evidence")
open_search()
press("Manual")
fill("Name", "Inline Regression Oats")
press("Done")
fill("Grams per serving (optional)", "40")
press("Done")
fill("Calories", "160")
press("Done")
press("Continue")
run("scroll", "top", "--settle")
capture(phase, "e12-manual")
press("Log Food")
capture(phase, "e12-manual-logged")
data = open_search()
search = next(n for n in data["nodes"] if n.get("kind") == "search")
run("fill", "@" + search["ref"] + "~s" + str(data["refsGeneration"]), "Inline Regression Oats", "--settle")
# clear-app-state can retain SwiftData; repeated identical saved fixtures are equivalent.
run("press", target("Inline Regression Oats, 160 kcal, P 0 • C 0 • F 0", "button"), "--settle")
capture(phase, "e12-saved")
run("scroll", "bottom", "--settle")
press("Grams")
capture(phase, "e12-grams")
press("Log Food")
capture(phase, "e12-grams-logged")
data = open_search()
search = next(n for n in data["nodes"] if n.get("kind") == "search")
run("fill", "@" + search["ref"] + "~s" + str(data["refsGeneration"]), "Banana", "--settle")
press("Banana, 105 kcal, P 1.3 • C 27 • F 0.4")
capture(phase, "e12-search")
fill("Calories", "200")
press("Done")
run("scroll", "bottom", "--settle")
data = capture(phase, "e12-common-copy")
assert any("Because you changed a common food" in n.get("label", "") for n in data["nodes"])
run("snapshot", "-i")
run("snapshot", "-i")
capture(phase, "e12-common-copy")
press("Log Food")
capture(phase, "e12-common-logged")
open_search()
data = capture(phase, "e12-reusable-created")
assert any("Banana, 200 kcal" in n.get("label", "") for n in data["nodes"])
print("E12: manual, saved, grams, search, common reusable copy PASS")
