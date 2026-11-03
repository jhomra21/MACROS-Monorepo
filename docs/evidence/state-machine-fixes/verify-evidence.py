"""Check retained evidence without printing possible credentials."""

from pathlib import Path
import re


root = Path(__file__).resolve().parent
workspace = root.parents[2]
patterns = [
    re.compile(r"(?<![0-9a-f])[0-9a-f]{32}(?![0-9a-f])", re.I),
    re.compile(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"),
    re.compile(r'"profileSecret"\s*:\s*"[A-Za-z0-9_-]{32,}"'),
]
text_files = [
    path for path in root.iterdir()
    if path.suffix in (".md", ".txt", ".ts", ".py")
]
hits = [
    path.name for path in text_files
    if any(pattern.search(path.read_text()) for pattern in patterns)
]
assert not hits, f"Possible secret patterns in evidence files: {hits}"
assert not (workspace / "build/state-machine-fixes/f3-private.json").exists()
files = [path for path in root.iterdir() if path.is_file()]
assert all(path.stat().st_size < 5_000_000 for path in files)
green = (root / "f3-green-after.txt").read_text()
assert '"Person removed"' in green
assert all(value not in green for value in ('"1234"', '"P 87 g"', '"C 146 g"', '"F 33 g"'))
red = (root / "f3-red-stale.txt").read_text()
assert all(value in red for value in ('"1234"', '"P 87 g"', '"C 146 g"', '"F 33 g"'))
assert "No sharing yet" in (root / "f3-red-roster.txt").read_text()
assert "zero relationships" in (root / "f3-green-server.txt").read_text()
assert "0 failures" in (root / "f2-green.txt").read_text()
print(f"PASS: {len(text_files)} text artifacts scanned; no credential patterns.")
print(f"PASS: {len(files)} evidence files below 5 MB; private state removed.")
print("PASS: F2 green and F3 red/green observations match retained transcripts.")
