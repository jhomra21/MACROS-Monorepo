#!/usr/bin/env python3
"""Refuse an App Review submission unless a non-Pro price check is recorded for that exact build.

Guards the 2026-11-11 rejection (2.1(a), "In-App purchases are unavailable"): build 23 was
submitted while every real-device purchase check was still open. Run before any submission:

    make submission-check BUILD=39 COMMIT=dc6b2bf

The record lives in docs/app-store/submission-checks.json. The screenshot stays outside the
public repository; only its SHA-256 is recorded. Pass SCREENSHOT=<path> to also verify the file.
"""
import argparse
import hashlib
import json
import re
import sys
from datetime import date, timedelta
from pathlib import Path

PLANS = ("yearly", "monthly", "lifetime")
ACCOUNT_TYPES = {"sandbox", "testflight"}
MAX_AGE_DAYS = 14
RECORD = Path(__file__).resolve().parents[2] / "docs/app-store/submission-checks.json"
EXAMPLE = """{
  "build": 39,
  "commit": "<full 40-character SHA of the archived commit>",
  "date": "YYYY-MM-DD",
  "device": "iPhone model, iOS version",
  "account": "sandbox or testflight (never an account that already owns Pro)",
  "prices": {"yearly": "$19.99/year", "monthly": "$2.99/month", "lifetime": "$49.99"},
  "purchaseButtonEnabled": true,
  "screenshotSha256": "<sha256 of the Settings > MACROS Pro screenshot>"
}"""


def fail(message: str) -> None:
    print(f"submission-check: FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", type=int, required=True)
    parser.add_argument("--commit", required=True, help="commit the submitted build was archived from (prefix allowed)")
    parser.add_argument("--screenshot", help="optional local path; its SHA-256 must match the record")
    parser.add_argument("--today", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if not re.fullmatch(r"[0-9a-f]{7,40}", args.commit):
        fail("--commit must be a hex SHA of at least 7 characters")
    if not RECORD.exists():
        fail(f"no record file {RECORD.name}; add a non-Pro price check entry like:\n{EXAMPLE}")
    try:
        checks = json.loads(RECORD.read_text(encoding="utf-8"))["checks"]
    except (json.JSONDecodeError, KeyError, TypeError) as error:
        fail(f"{RECORD.name} must be {{\"checks\": [...]}}: {error}")

    entries = [c for c in checks if c.get("build") == args.build]
    if not entries:
        fail(f"no non-Pro price check recorded for build {args.build}; add one like:\n{EXAMPLE}")
    entry = entries[-1]

    commit = str(entry.get("commit", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        fail(f"build {args.build}: record commit must be a full 40-character SHA")
    if not commit.startswith(args.commit):
        fail(f"build {args.build}: price check was done on {commit[:12]}, not on {args.commit}")

    try:
        checked = date.fromisoformat(str(entry.get("date")))
    except ValueError:
        fail(f"build {args.build}: date must be YYYY-MM-DD")
    today = date.fromisoformat(args.today) if args.today else date.today()
    if checked > today:
        fail(f"build {args.build}: check date {checked} is in the future")
    if today - checked > timedelta(days=MAX_AGE_DAYS):
        fail(f"build {args.build}: price check from {checked} is older than {MAX_AGE_DAYS} days; repeat it")

    if entry.get("account") not in ACCOUNT_TYPES:
        fail(f"build {args.build}: account must be one of {sorted(ACCOUNT_TYPES)}")
    if not str(entry.get("device", "")).strip():
        fail(f"build {args.build}: device and iOS version are required")

    prices = entry.get("prices") or {}
    for plan in PLANS:
        price = str(prices.get(plan, "")).strip()
        if not price or not re.search(r"\d", price) or re.search(r"unavailable|loading", price, re.IGNORECASE):
            fail(f"build {args.build}: {plan} price was {price or 'missing'!r}; every plan must show a real price")
    if entry.get("purchaseButtonEnabled") is not True:
        fail(f"build {args.build}: the purchase button must have been enabled")

    digest = str(entry.get("screenshotSha256", "")).lower()
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        fail(f"build {args.build}: screenshotSha256 must be a SHA-256 hex digest")
    if args.screenshot:
        path = Path(args.screenshot)
        if not path.is_file():
            fail(f"screenshot not found: {path}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            fail(f"screenshot {path.name} does not match the recorded SHA-256")

    print(f"submission-check: ok, build {args.build} ({commit[:12]}) showed all three prices to a non-Pro "
          f"{entry['account']} account on {checked}")


if __name__ == "__main__":
    main()
