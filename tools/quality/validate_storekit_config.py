#!/usr/bin/env python3
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


EXPECTED_PRODUCT_IDS = {"macros.pro.yearly", "macros.pro.monthly", "macros.pro.lifetime", "fullunlock001"}
EXPECTED_SCHEME_IDENTIFIER = "../../MACROSPro.storekit"


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

    # Runtime-confirmed: Xcode resolves shared-scheme identifiers from xcshareddata.
    storekit_path = (scheme_path.parent.parent / identifier).resolve()
    try:
        with storekit_path.open() as file:
            storekit_config = json.load(file)
    except FileNotFoundError:
        fail(f"StoreKit configuration does not exist: {identifier} -> {storekit_path}")
    except json.JSONDecodeError as error:
        fail(f"StoreKit configuration JSON is invalid: {error}")

    groups = storekit_config.get("subscriptionGroups", [])
    if len(groups) != 1 or groups[0].get("name") != "MACROS Pro":
        fail("configuration must contain one MACROS Pro subscription group")
    subscriptions = groups[0].get("subscriptions", [])
    products = storekit_config.get("products", []) + subscriptions
    by_id = {product.get("productID"): product for product in products}
    if set(by_id) != EXPECTED_PRODUCT_IDS or len(products) != len(EXPECTED_PRODUCT_IDS):
        fail(f"expected exactly {sorted(EXPECTED_PRODUCT_IDS)}, got {sorted(by_id)}")
    for product_id, price, period in [
        ("macros.pro.yearly", "19.99", "P1Y"),
        ("macros.pro.monthly", "2.99", "P1M"),
    ]:
        product = by_id[product_id]
        if (product.get("displayPrice") != price
                or product.get("recurringSubscriptionPeriod") != period
                or product.get("type") != "RecurringSubscription"
                or product.get("subscriptionGroupID") != groups[0].get("id")):
            fail(f"invalid price, period, type, or group for {product_id}")
    intro = by_id["macros.pro.yearly"].get("introductoryOffer") or {}
    if (intro.get("paymentMode") != "free"
            or intro.get("subscriptionPeriod") != "P1W"
            or intro.get("numberOfPeriods") != 1):
        fail("yearly must offer one free week")
    if by_id["macros.pro.monthly"].get("introductoryOffer") is not None:
        fail("monthly must not have an introductory offer")
    lifetime = by_id["macros.pro.lifetime"]
    if (lifetime.get("displayPrice") != "49.99"
            or lifetime.get("type") != "NonConsumable"
            or lifetime.get("familyShareable") is not True):
        fail("lifetime must be a family-shareable $49.99 non-consumable")
    if by_id["fullunlock001"].get("type") != "NonConsumable":
        fail("legacy unlock must remain a non-consumable")

    project_path = root / "cal-macro-tracker.xcodeproj/project.pbxproj"
    project_text = project_path.read_text()
    storekit_reference_count = project_text.count("/* MACROSPro.storekit */ = {isa = PBXFileReference;")
    if storekit_reference_count != 1:
        fail(f"project must contain exactly one MACROSPro.storekit file reference, found {storekit_reference_count}")

    store_text = purchase_store_path.read_text()
    for product_id in EXPECTED_PRODUCT_IDS:
        if f'"{product_id}"' not in store_text:
            fail(f"PurchaseStore is missing product ID {product_id}")
    for plan in ("yearly", "monthly", "lifetime"):
        if re.search(rf'case\s+\.{plan}:\s*"macros\.pro\.{plan}"', store_text) is None:
            fail(f"ProPlan.{plan} must map to macros.pro.{plan}")
    if re.search(r'static\s+let\s+legacyFullUnlockProductID\s*=\s*"fullunlock001"', store_text) is None:
        fail("PurchaseStore must explicitly retain the legacy product")
    if "FullUnlock.storekit" in project_text:
        fail("project still references the old catalog")
    if project_text.count("/* MACROSPro.storekit in Resources */ = {isa = PBXBuildFile;") != 1:
        fail("test bundle must include exactly one catalog resource")
    resource_phase = re.search(
        r'3D0000000000000000000006 /\* Resources \*/ = \{(.*?)\n\t\t\};',
        project_text, re.DOTALL,
    )
    if resource_phase is None or "/* MACROSPro.storekit in Resources */" not in resource_phase[1]:
        fail("catalog resource must belong to the test target")

    print(f"storekit-config: valid ({identifier} -> {storekit_path})")


if __name__ == "__main__":
    main()
