#!/bin/sh
# Guards the 2026-11-11 App Review rejection (2.1(a), "In-App purchases are unavailable").
# 1. Only PurchaseStore may ask StoreKit for products, so every load goes through its
#    launch prefetch, bounded retries, hard deadline and diagnostics.
# 2. Only the paywall's planPriceLabel may say "Unavailable", so no row shows it while
#    products are still loading.
set -eu

root="${1:-cal-macro-tracker}"
loader="$root/Features/Purchases/PurchaseStore.swift"
label_file="$root/Features/Purchases/ProPaywallSheet.swift"
status=0

loaders=$(grep -rn --include='*.swift' 'Product\.products(for' "$root" | grep -v "^$loader:" || true)
if [ -n "$loaders" ]; then
  echo "error: call Product.products(for:) only from $loader (use PurchaseStore.loadProducts()):" >&2
  echo "$loaders" >&2
  status=1
fi

if ! grep -q 'Product\.products(for' "$loader"; then
  echo "error: $loader no longer loads products; update this check with the new single loader" >&2
  status=1
fi

unavailable=$(grep -rn --include='*.swift' '"Unavailable"' "$root/Features/Purchases" | grep -v 'isLoading ? "Loading…" : "Unavailable"' || true)
if [ -n "$unavailable" ]; then
  echo "error: show \"Unavailable\" for a plan only through ProPaywallSheet.planPriceLabel(isLoading:price:) in $label_file:" >&2
  echo "$unavailable" >&2
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "storekit product loading: ok"
fi
exit "$status"
