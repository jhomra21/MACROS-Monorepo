import json
from pathlib import Path

root = Path(__file__).resolve().parent


def nodes(path):
    text = (root / path).read_text()
    tree = json.loads(text.split("```json\n", 1)[1].split("```", 1)[0])

    def walk(node):
        yield node
        for child in node.get("children", []):
            yield from walk(child)

    return [node for branch in tree for node in walk(branch)]


for device in ("a", "b"):
    def invite_fields(which):
        return [
            node["AXLabel"]
            for node in nodes(f"{device}-{which}-settings.json.txt")
            if (node.get("AXLabel") or "").startswith(("calmacrotracker://", "Expires "))
        ]

    first = invite_fields("first")
    assert len(first) == 2
    assert first == invite_fields("second")
    revoked = [node.get("AXLabel") for node in nodes(f"{device}-revoked.json.txt")]
    assert "Revoke Invite" not in revoked
    assert "Share Invite" not in revoked
    assert "Sharing Failed" not in revoked
    print(f"{device.upper()}: identical URL/expiry; evidence link revoked")

people = [node.get("AXLabel", "") or "" for node in nodes("b-people.json.txt")]
assert sum(label.startswith("Test A,") for label in people) == 1
summary = json.loads((root / "test-summary.json").read_text())
assert summary["passedTests"] == 228 and summary["failedTests"] == 0
assert "Two acceptors and repeat acceptance passed." in (root / "smoke.log").read_text()
assert "Sharing smoke passed." in (root / "smoke.log").read_text()
for phase in ("before", "after"):
    assert "No issues found." in (root / f"insights-{phase}.log").read_text()
print("Single Test A connection, 228 passing app tests, HTTP smoke and healthy insights verified")
