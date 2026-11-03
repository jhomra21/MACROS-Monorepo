"""Compare a captured E12 phase to baseline. Requires Pillow; no device interaction."""
import json
import pathlib
import sys
from PIL import Image, ImageChops

root = pathlib.Path(__file__).resolve().parent
phase = sys.argv[1] if len(sys.argv) > 1 else "extraction"


def normalized(path):
    data = json.loads(path.read_text())
    keys = ["parentIndex", "type", "role", "subrole", "label", "value", "identifier",
            "rect", "enabled", "depth", "kind", "selected", "checked", "hittable", "focused"]
    result = []
    for node in data["nodes"]:
        stable = {key: node[key] for key in keys if key in node}
        if "rect" in stable:
            stable["rect"] = {key: round(value, 3) for key, value in stable["rect"].items()}
        result.append(stable)
    schema = "UIKit-class-role" if data["nodes"][0].get("role") else "XCTest-normalized"
    return result, schema


results = []
for scenario in ["e12-manual", "e12-saved", "e12-grams", "e12-search", "e12-common-copy"]:
    before = Image.open(root / "baseline" / (scenario + ".png")).convert("RGB")
    after = Image.open(root / phase / (scenario + ".png")).convert("RGB")
    assert before.size == after.size
    difference = ImageChops.difference(before.crop((0, 47, *before.size)), after.crop((0, 47, *after.size)))
    before_tree, before_schema = normalized(root / "baseline" / (scenario + ".json"))
    after_tree, after_schema = normalized(root / phase / (scenario + ".json"))
    pixels = difference.tobytes()
    results.append({"scenario": scenario, "app_pixel_difference_bounds": difference.getbbox(),
                    "tree_identical": before_tree == after_tree,
                    "tree_comparable": before_schema == after_schema,
                    "snapshot_schemas": [before_schema, after_schema],
                    "tree_comparison": "compared" if before_schema == after_schema else "unavailable across backend schemas",
                    "changed_pixel_count": sum(any(pixels[index:index + 3]) for index in range(0, len(pixels), 3)),
                    "maximum_rgb_difference": [high for low, high in difference.getextrema()]})
(root / phase / "comparison.json").write_text(json.dumps(results, indent=2) + "\n")
print(json.dumps(results, indent=2))
assert all(result["tree_identical"] for result in results if result["tree_comparable"]), "E12 accessibility tree regression"
assert all(result["app_pixel_difference_bounds"] is None for result in results
           if result["scenario"] != "e12-common-copy"), "E12 app pixel regression"
