#!/usr/bin/env python3
"""Deterministic loopback stand-in for the MACROS lookup proxy, used by the delete-saved-foods E2E.

Usage:
  python3 fixture-proxy.py serve <port>       # point PACKAGED_FOOD_SEARCH_BASE_URL_OVERRIDE at http://127.0.0.1:<port>
  python3 fixture-proxy.py barcode <out.png>  # EAN-13 image of the fixture product, for the Camera photo picker

One product exists under two providers, like a real USDA branded food and its Open Food Facts entry:
USDA search returns it with barcode 0012345678905 (13 digits) and ID usda:999001; the Open Food Facts barcode
lookup returns it with ID openfoodfacts:012345678905. Search also returns a long-named food for layout checks.
"""
import json
import struct
import sys
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

BARCODE = "0012345678905"
NUTRITION = {"calories": 150, "protein": 17, "fat": 2, "carbs": 15, "saturatedFat": 1.2, "fiber": 0, "sugars": 11,
             "addedSugars": 5, "sodium": 85, "cholesterol": 10}


def search_result(fdc_id, name, barcode):
    return {
        "id": f"usda:{fdc_id}", "source": "usda", "externalProductID": f"usda:{fdc_id}",
        "sourceName": "USDA FoodData Central", "sourceURL": f"https://fdc.nal.usda.gov/food-details/{fdc_id}/nutrients",
        "name": name, "brand": "Fixture Dairy", "barcode": barcode, "servingDescription": "1 container (170 g)",
        "gramsPerServing": 170, "nutrition": NUTRITION, "requiredReviewNutrients": [],
    }


SEARCH_RESULTS = [
    search_result(999001, "Fixture Skyr Yogurt", BARCODE),
    search_result(999002, "Fixture Extra Creamy Vanilla Bean Greek Style Strained Yogurt with Wildflower Honey and "
                          "Toasted Almonds, Family Size Multipack", None),
]

OFF_PRODUCT = {
    "externalProductID": "openfoodfacts:012345678905", "code": BARCODE, "product_name": "Fixture Skyr Yogurt",
    "brands": "Fixture Dairy", "serving_size": "170 g", "serving_quantity": 170, "serving_quantity_unit": "g",
    "url": f"https://world.openfoodfacts.org/product/{BARCODE}",
    "nutriments": {"energy-kcal_serving": 150, "proteins_serving": 17, "fat_serving": 2, "carbohydrates_serving": 15},
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        parts = [p for p in url.path.split("/") if p]
        if parts == ["v2", "foods", "search"]:
            query = parse_qs(url.query).get("q", [""])[0].lower()
            results = [r for r in SEARCH_RESULTS if all(w in r["name"].lower() for w in query.split())]
            return self.send(200, {"query": query, "results": results, "nextCursor": None})
        if parts[:3] == ["v1", "packaged-foods", "barcodes"] and len(parts) == 4:
            if parts[3] in (BARCODE, BARCODE[1:]):
                return self.send(200, {"product": OFF_PRODUCT})
            return self.send(404, {"error": "No product was found for that barcode."})
        return self.send(404, {"error": "not found"})

    def send(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


L = ["0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011"]
PARITY = ["LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG", "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"]


def ean13_modules(code):
    digits = [int(c) for c in code]
    right = lambda d: "".join("1" if b == "0" else "0" for b in L[d])
    left = "".join(L[d] if p == "L" else right(d)[::-1] for d, p in zip(digits[1:7], PARITY[digits[0]]))
    return "101" + left + "01010" + "".join(right(d) for d in digits[7:]) + "101"


def write_barcode_png(path, code=BARCODE, module=8, quiet=20, bar_height=480, width=1600, height=1200):
    modules = ean13_modules(code)
    left = (width - len(modules) * module) // 2
    top = (height - bar_height) // 2
    row_bar = bytearray([255] * width)
    for i, m in enumerate(modules):
        if m == "1":
            row_bar[left + i * module:left + (i + 1) * module] = bytes([0] * module)
    blank = bytes([255] * width)
    raw = b"".join(b"\x00" + (bytes(row_bar) if top <= y < top + bar_height else blank) for y in range(height))
    chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("serve", "barcode"):
        sys.exit("usage: fixture-proxy.py serve <port> | barcode <png>")
    if sys.argv[1] == "serve":
        ThreadingHTTPServer(("127.0.0.1", int(sys.argv[2])), Handler).serve_forever()
    elif sys.argv[1] == "barcode":
        write_barcode_png(sys.argv[2])
