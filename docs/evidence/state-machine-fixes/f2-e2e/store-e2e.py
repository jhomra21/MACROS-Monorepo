"""Simulator B only, lock required. Terminate the app before prepare/save-fixture."""
import hashlib
import json
import pathlib
import shutil
import sqlite3
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
EVIDENCE = pathlib.Path(__file__).resolve().parent
FIXTURE = ROOT / "build/review-fixes/fixture"
UDID = "F976E800-DA1F-4F20-B755-DFD964E33975"
BUNDLE = "juan-test.cal-macro-tracker"


def container(kind):
    output = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", UDID, BUNDLE, kind], text=True
    ).strip()
    return pathlib.Path(output.split("\t")[-1])


# ModelConfiguration(nil, groupContainer: .none / .identifier(...)) defaults.
LEGACY = container("data") / "Library/Application Support/default.store"
SHARED = container("groups") / "Library/Application Support/default.store"


def artifact(base, suffix):
    return pathlib.Path(str(base) + suffix)


def hashes(base):
    return {
        suffix or "base": hashlib.sha256(artifact(base, suffix).read_bytes()).hexdigest()
        for suffix in ("", "-wal")
    }


def inspect(base):
    connection = sqlite3.connect("file:" + str(base) + "?mode=ro", uri=True)
    try:
        return {
            "count": connection.execute("SELECT COUNT(*) FROM ZLOGENTRY").fetchone()[0],
            "sample": connection.execute(
                "SELECT ZFOODNAME,ZCALORIESCONSUMED FROM ZLOGENTRY ORDER BY ZDATELOGGED DESC LIMIT 1"
            ).fetchone(),
            "metadata_rows": connection.execute("SELECT COUNT(*) FROM Z_METADATA").fetchone()[0],
        }
    finally:
        connection.close()


action = sys.argv[1]
if action == "save-fixture":
    FIXTURE.mkdir(parents=True, exist_ok=True)
    for suffix in ("", "-wal"):
        shutil.copy2(artifact(SHARED, suffix), FIXTURE / ("default.store" + suffix))
    result = inspect(SHARED)
    (EVIDENCE / "expected.json").write_text(json.dumps(result, indent=2) + "\n")
    print("Main Debug demo store:", json.dumps(result))
elif action == "prepare":
    label = sys.argv[2]
    LEGACY.parent.mkdir(parents=True, exist_ok=True)
    for base in (LEGACY, SHARED):
        for suffix in ("", "-wal", "-shm"):
            artifact(base, suffix).unlink(missing_ok=True)
    for suffix in ("", "-wal"):
        shutil.copy2(FIXTURE / ("default.store" + suffix), artifact(LEGACY, suffix))
    assert not artifact(LEGACY, "-shm").exists()
    before = hashes(LEGACY)
    (EVIDENCE / (label + "-legacy-before.json")).write_text(json.dumps(before, indent=2) + "\n")
    print(label, "copied real SwiftData base + WAL, deliberately no SHM; removed shared base/WAL/SHM")
    print("legacy hashes before:", json.dumps(before))
    if label == "red-base-only":
        # Reproduce the old copier's interrupted publication, without killing
        # an unrelated process: copy base + WAL, then lose destination WAL.
        for suffix in ("", "-wal"):
            shutil.copy2(artifact(LEGACY, suffix), artifact(SHARED, suffix))
        artifact(SHARED, "-wal").unlink()
        print("Simulated interrupted old copy: shared base exists, shared WAL removed; legacy WAL retained.")
elif action == "verify":
    label = sys.argv[2]
    before = json.loads((EVIDENCE / (label + "-legacy-before.json")).read_text())
    after = hashes(LEGACY)
    assert before == after, "Legacy base/WAL changed"
    observed = inspect(SHARED)
    expected = json.loads((EVIDENCE / "expected.json").read_text())
    matches = observed["count"] == expected["count"] and list(observed["sample"] or []) == expected["sample"]
    result = {
        "case": label, "observed": observed, "matches_demo": matches,
        "legacy_base_and_wal_unchanged": before == after, "legacy_after": after,
    }
    (EVIDENCE / (label + "-result.json")).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    if label in ("green", "red-full"):
        assert matches
    elif label == "red-base-only":
        assert not matches, "Expected the old skip-if-base-exists path to lose WAL-only entries"
else:
    raise SystemExit("Use save-fixture, prepare LABEL, or verify LABEL")
