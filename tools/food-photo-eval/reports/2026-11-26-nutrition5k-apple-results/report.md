# Nutrition5k scoring

Generated 2026-11-26T23:21:48.064Z.

### Calories and mass (answered dishes)

| Arm | Dishes | Answered | Failed | Refused/empty | kcal MAPE | kcal median APE | kcal bias | Within ±20% | Within ±20% (all dishes) | Mass MAPE | Mass bias |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| apple-on-device | 60 | 60 | 0 | 0 | 75.2% | 60.7% | 7.6% | 15.0% | 15.0% | 50.0% | -3.0% |
| apple-on-device-known | 60 | 60 | 0 | 0 | 58.4% | 51.5% | 12.0% | 25.0% | 25.0% | 54.5% | 9.5% |
| apple-private-cloud | 60 | 0 | 60 | 0 | n/a | n/a | n/a | n/a | 0.0% | n/a | n/a |
| apple-private-cloud-known | 60 | 0 | 60 | 0 | n/a | n/a | n/a | n/a | 0.0% | n/a | n/a |

### Recognition and portions (answered dishes)

| Arm | Count recall | Count precision | Mass recall | Mass precision | Matched-item gram median APE | …for items ≥ 10 g | Unpriced predicted mass | p50 / p95 ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| apple-on-device | 22.0% | 63.8% | 48.1% | 66.6% | 60.0% | 57.9% | 6.3% | 2925 / 6419 |
| apple-on-device-known | 98.6% | 99.5% | 100.0% | 99.9% | 89.4% | 55.7% | 0.0% | 4651 / 21088 |
| apple-private-cloud | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a / n/a |
| apple-private-cloud-known | n/a | n/a | n/a | n/a | n/a | n/a | n/a | n/a / n/a |

### kcal MAPE by ingredient count (n answered)

| Arm | 1-2 | 3-5 | 6+ |
|---|---:|---:|---:|
| apple-on-device | 69.3% (20) | 74.5% (20) | 81.8% (20) |
| apple-on-device-known | 43.1% (20) | 60.8% (20) | 71.2% (20) |
| apple-private-cloud | n/a (0) | n/a (0) | n/a (0) |
| apple-private-cloud-known | n/a (0) | n/a (0) | n/a (0) |

### Name-match methods (matched pairs)

| Arm | exact | alias | contains | fuzzy |
|---|---:|---:|---:|---:|
| apple-on-device | 52 | 15 | 14 | 0 |
| apple-on-device-known | 363 | 1 | 0 | 0 |
| apple-private-cloud | 0 | 0 | 0 | 0 |
| apple-private-cloud-known | 0 | 0 | 0 | 0 |

### Failure analysis


#### apple-on-device

- Most missed truth ingredients: olive oil ×21 (83 g), salt ×18 (9 g), garlic ×13 (20 g), onions ×10 (123 g), pepper ×9 (16 g), vinegar ×9 (15 g), broccoli ×7 (171 g), parsley ×7 (5 g), wheat berry ×6 (266 g), lemon juice ×6 (4 g)
- Most frequent unmatched predictions: meat ×4, cherry tomato ×3, roasted vegetable ×3, crouton ×3, cheese ×3, cucumber ×2, lettuce ×2, apple ×2, vegetable ×2, blueberry ×2

#### apple-on-device-known

- Most missed truth ingredients: salt ×2 (0 g), olive oil ×1 (4 g), vinaigrette ×1 (3 g), pepper ×1 (0 g)
- Most frequent unmatched predictions: chicken ×1, apple ×1

#### apple-private-cloud

- Most missed truth ingredients: none
- Most frequent unmatched predictions: none
- Failure messages: `Error Domain=FoundationModels.LanguageModelError Code=-1 "The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)" UserInfo={NSMult`; `Error Domain=FoundationModels.LanguageModelError Code=-1 "The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)" UserInfo={NSLoca`

#### apple-private-cloud-known

- Most missed truth ingredients: none
- Most frequent unmatched predictions: none
- Failure messages: `Error Domain=FoundationModels.LanguageModelError Code=-1 "The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)" UserInfo={NSLoca`; `Error Domain=FoundationModels.LanguageModelError Code=-1 "The operation couldn’t be completed. (FoundationModels.LanguageModelError error -1.)" UserInfo={NSMult`
