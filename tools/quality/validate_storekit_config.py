#!/usr/bin/env python3
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


EXPECTED_PRODUCT_ID = "juan-test.cal-macro-tracker.full-unlock"
EXPECTED_SCHEME_IDENTIFIER = "../../FullUnlock.storekit"


def fail(message: str) -> None:
    print(f"storekit-config: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    scheme_path = root / "cal-macro-tracker.xcodeproj/xcshareddata/xcschemes/cal-macro-tracker.xcscheme"
    purchase_store_path = root / "cal-macro-tracker/Features/Purchases/PurchaseStore.swift"

    try:
        scheme = ET.parse(scheme_path).getroot()
    except FileNotFoundError:
        fail(f"missing scheme at {scheme_path}")
    except ET.ParseError as error:
        fail(f"scheme XML is invalid: {error}")

    storekit_reference = scheme.find(".//StoreKitConfigurationFileReference")
    if storekit_reference is None:
        fail("scheme is missing StoreKitConfigurationFileReference")

    identifier = storekit_reference.attrib.get("identifier")
    if not identifier:
        fail("StoreKitConfigurationFileReference is missing identifier")
    if identifier != EXPECTED_SCHEME_IDENTIFIER:
        fail(f"scheme StoreKit identifier must be {EXPECTED_SCHEME_IDENTIFIER}, got {identifier}")

    xcode_project_workspace_path = root / "cal-macro-tracker.xcodeproj/project.xcworkspace"
    storekit_path = (xcode_project_workspace_path / identifier).resolve()
    try:
        with storekit_path.open() as file:
            storekit_config = json.load(file)
    except FileNotFoundError:
        fail(f"StoreKit configuration does not exist: {identifier} -> {storekit_path}")
    except json.JSONDecodeError as error:
        fail(f"StoreKit configuration JSON is invalid: {error}")

    product_ids = {
        product.get("productID")
        for product in storekit_config.get("products", [])
        if isinstance(product, dict)
    }
    if EXPECTED_PRODUCT_ID not in product_ids:
        fail(f"{storekit_path.name} is missing product ID {EXPECTED_PRODUCT_ID}")

    project_path = root / "cal-macro-tracker.xcodeproj/project.pbxproj"
    project_text = project_path.read_text()
    storekit_reference_count = project_text.count("/* FullUnlock.storekit */ = {isa = PBXFileReference;")
    if storekit_reference_count != 1:
        fail(f"project must contain exactly one FullUnlock.storekit file reference, found {storekit_reference_count}")

    expected_assignment = rf'static\s+let\s+fullUnlockProductID\s*=\s*"{re.escape(EXPECTED_PRODUCT_ID)}"'
    if re.search(expected_assignment, purchase_store_path.read_text()) is None:
        fail(f"PurchaseStore.fullUnlockProductID does not match {EXPECTED_PRODUCT_ID}")

    print(f"storekit-config: valid ({identifier} -> {storekit_path})")


if __name__ == "__main__":
    main()
