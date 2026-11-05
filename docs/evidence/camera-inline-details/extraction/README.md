# Extraction verification

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/camera-inline-details/extraction/e12-common-copy.png`.

E12 ran against the preserved d53a313 app and the extraction app using e12.py. Manual → Continue → Log, saved food → Log, grams → Log, search → Log, and edited common food → automatic reusable copy all passed. Normalized accessibility trees are identical for the five editor states. The four top/quantity captures have identical app pixels (excluding the changing system clock). The common-copy capture has a small native glass button-edge rendering difference, with identical geometry, copy, controls and state; it is not claimed pixel-identical. comparison.json records it exactly.

CameraCardLayoutTests passed on both builds. heights.csv is byte-identical for all 960 measurements.
