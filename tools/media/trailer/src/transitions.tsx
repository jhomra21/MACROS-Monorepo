import React from "react";
import { AbsoluteFill, Easing, interpolate, useCurrentFrame } from "remotion";
import { FPS, SHOTS } from "./shots";
import { STYLE } from "./styles";

/** Frames a transition of `length` frames spends before its cut; it ends `length - before` frames after it. */
export const before = (length: number) => Math.ceil(length / 2);

const cuts = SHOTS.slice(1).map((to, i) => ({ frame: to.start * FPS, from: SHOTS[i], to }));
const ease = Easing.bezier(0.65, 0, 0.35, 1);
const { x, y } = STYLE.discOrigin;
const FULL_RADIUS = Math.hypot(Math.max(x, 1080 - x), Math.max(y, 1920 - y));

/** The colour change in progress at `frame`: the outgoing colour, and the incoming one as a disc that reaches full size on the change's last frame. */
function colorChange(frame: number) {
  const start = (cut: number) => cut - before(STYLE.colorFrames);
  const active = cuts.find((cut) => frame >= start(cut.frame) && frame < start(cut.frame) + STYLE.colorFrames);
  if (!active) return { base: SHOTS.find((shot) => frame >= shot.start * FPS && frame < shot.end * FPS)?.color ?? SHOTS[0].color };
  const progress = ease((frame - start(active.frame)) / (STYLE.colorFrames - 1));
  return { base: active.from.color, disc: { color: active.to.color, radius: progress * FULL_RADIUS } };
}

const Disc: React.FC<{ color: string; radius: number }> = ({ color, radius }) =>
  <AbsoluteFill style={{ background: color, clipPath: `circle(${radius}px at ${x}px ${y}px)` }} />;

/** The colour field, always behind the phone. The next colour grows as a disc from the phone's centre, so the phone stays put. */
export const Backdrop: React.FC = () => {
  const { base, disc } = colorChange(useCurrentFrame());
  return <AbsoluteFill style={{ background: base }}>{disc && <Disc color={disc.color} radius={disc.radius} />}</AbsoluteFill>;
};

/** 0 to 1 over the `STYLE.screenFrames` around `cut` (a frame number). */
export const screenFade = (frame: number, cut: number) =>
  interpolate(frame, [cut - before(STYLE.screenFrames), cut - before(STYLE.screenFrames) + STYLE.screenFrames - 1], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
