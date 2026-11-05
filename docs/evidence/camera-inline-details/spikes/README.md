# Spike results

Media removed in the repo cleanup; retrieve with `git show 074b10994f1b68d9d7a8d6c54ed7effb90d5f1f5:docs/evidence/camera-inline-details/spikes/s1-transparent-form.png`.

Run order: S1, S3, S2, S4, on iPhone 17e B / iOS 27. S1: transparent Form passes with rowBackground .clear; no fallback fork needed. S3: frame morph and software-keyboard avoidance pass: camera strip consumes zero layout height. The prototype exposes the presenting dashboard behind the keyboard accessory safe-area gap, so the production sheet keeps its existing full-screen black background rather than the prototype's geometry-only background. S2: Next moved focus from Name to Brand, Previous enabled, Done restored the expanded layout. S4: the one glass shape tracks the animated frame; no second surface or tint. See individual PNG/tree captures and spikes.mp4. The prototype was removed from application source after capture.
