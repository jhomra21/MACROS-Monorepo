# Nutrition5k scoring

Generated 2026-11-27T01:23:28.014Z.

### Calories and mass (answered dishes)

| Arm | Dishes | Answered | Failed | Refused/empty | kcal MAPE | kcal median APE | kcal bias | Within ±20% | Within ±20% (all dishes) | Mass MAPE | Mass bias |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| gemini-gemini-3.5-flash-lite | 60 | 60 | 0 | 0 | 28.4% | 22.6% | -11.2% | 45.0% | 45.0% | 25.2% | -14.8% |
| gemini-gemini-3.8-flash | 60 | 21 | 39 | 0 | 23.2% | 17.9% | 8.6% | 57.1% | 20.0% | 19.1% | 5.4% |

### Recognition and portions (answered dishes)

| Arm | Count recall | Count precision | Mass recall | Mass precision | Matched-item gram median APE | …for items ≥ 10 g | Unpriced predicted mass | p50 / p95 ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| gemini-gemini-3.5-flash-lite | 37.4% | 80.7% | 73.3% | 83.8% | 29.4% | 29.3% | 1.6% | 1787 / 2609 |
| gemini-gemini-3.8-flash | 57.5% | 87.7% | 94.4% | 94.5% | 21.2% | 21.2% | 0.0% | 25021 / 85291 |

### kcal MAPE by ingredient count (n answered)

| Arm | 1-2 | 3-5 | 6+ |
|---|---:|---:|---:|
| gemini-gemini-3.5-flash-lite | 29.4% (20) | 26.8% (20) | 29.0% (20) |
| gemini-gemini-3.8-flash | 25.8% (11) | 17.4% (8) | 32.0% (2) |

### Name-match methods (matched pairs)

| Arm | exact | alias | contains | fuzzy |
|---|---:|---:|---:|---:|
| gemini-gemini-3.5-flash-lite | 85 | 12 | 39 | 2 |
| gemini-gemini-3.8-flash | 34 | 1 | 15 | 0 |

### Failure analysis


#### gemini-gemini-3.5-flash-lite

- Most missed truth ingredients: olive oil ×21 (83 g), salt ×18 (9 g), garlic ×14 (21 g), pepper ×9 (16 g), vinegar ×9 (15 g), onions ×7 (15 g), parsley ×7 (5 g), wheat berry ×6 (266 g), lemon juice ×6 (4 g), broccoli ×5 (87 g)
- Most frequent unmatched predictions: roasted potato ×3, strawberry ×2, blueberry ×2, mozzarella cheese ×2, blackberry ×1, raspberry ×1, melon chunk ×1, brown rice vegetable ×1, grain dish vegetable ×1, mixed green salad ×1

#### gemini-gemini-3.8-flash

- Most missed truth ingredients: chard ×2 (27 g), olive oil ×2 (7 g), salt ×2 (1 g), lemon juice ×2 (1 g), vinegar ×2 (1 g), garlic ×2 (1 g), basil ×2 (0 g), rosemary ×2 (0 g), sweet potato ×1 (110 g), berries ×1 (68 g)
- Most frequent unmatched predictions: roasted potato ×1, blackberry ×1, raspberry ×1, cantaloupe melon ×1, mixed green salad ×1, kale ×1, quinoa ×1
- Failure messages: `You exceeded your current quota, please check your plan and billing details. For more information on this error, head to: https://aistudio.google.com/docs/rate-`; `This model is currently experiencing high demand. Spikes in demand are usually temporary. Please try again later.`
