"""Replays GoalCalculator.macroGrams for every whole-kcal target and reports realized energy shares.

Usage: python3 docs/evidence/amdr-macro-presets/preset-shares.py
Mirrors cal-macro-tracker/Features/Onboarding/GoalCalculator.swift: Swift's .rounded() is
half-away-from-zero, so Python's banker's round() is not used.
"""
import math

PRESETS = {"Balanced": (20, 50, 30), "High protein": (31, 47, 22), "Higher fat": (20, 47, 33)}
# Exact-edge alternatives rejected because 5 g rounding moved saved shares outside the AMDR.
EDGE_PRESETS = {"High protein (edge)": (35, 45, 20), "Higher fat (edge)": (20, 45, 35)}
AMDR = {"protein": (10, 35), "carbs": (45, 65), "fat": (20, 35)}


def round_half_away(x):
    return math.floor(x + 0.5) if x >= 0 else math.ceil(x - 0.5)


def to_five(x):
    return round_half_away(x / 5) * 5


def grams(cal, p, c, f):
    protein, fat = to_five(cal * p / 400), to_five(cal * f / 900)
    carbs = to_five(cal * c / 400)
    need = cal - (protein * 4 + fat * 9)
    if not (carbs * 4 >= need and carbs * 4 <= need + cal * 0.02):
        carbs = math.ceil(need / 20) * 5
    return protein, carbs, fat


for name, (p, c, f) in {**PRESETS, **EDGE_PRESETS}.items():
    assert p + c + f == 100
    for macro, value in zip(AMDR, (p, c, f)):
        lo, hi = AMDR[macro]
        assert lo <= value <= hi, (name, macro, value)
    worst = {m: [100.0, 0.0] for m in AMDR}
    outside = 0
    for cal in range(1200, 4501):
        pg, cg, fg = grams(cal, p, c, f)
        total = pg * 4 + cg * 4 + fg * 9
        assert cal <= total <= cal * 1.02 + 1e-9
        shares = {"protein": pg * 400 / total, "carbs": cg * 400 / total, "fat": fg * 900 / total}
        if any(not (AMDR[m][0] <= s <= AMDR[m][1]) for m, s in shares.items()):
            outside += 1
        for m, s in shares.items():
            worst[m][0] = min(worst[m][0], s)
            worst[m][1] = max(worst[m][1], s)
    ranges = ", ".join(f"{m} {lo:.2f}-{hi:.2f}%" for m, (lo, hi) in worst.items())
    print(f"{name} {p}/{c}/{f}: definition within AMDR; realized {ranges}; {outside}/3301 targets have a share outside the AMDR")

print("Worked example (Male, 30, 70 kg, 175 cm, Moderate, Maintain):")
cal = (10 * 70 + 6.25 * 175 - 5 * 30 + 5) * 1.55
for name, (p, c, f) in PRESETS.items():
    pg, cg, fg = grams(cal, p, c, f)
    print(f"  {name}: {cal:.2f} kcal -> P {cal*p/400:.2f} C {cal*c/400:.2f} F {cal*f/900:.2f} before rounding -> {pg}/{cg}/{fg} g, {pg*4+cg*4+fg*9} kcal")
