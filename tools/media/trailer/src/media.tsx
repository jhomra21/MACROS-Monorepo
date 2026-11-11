import React from "react";
import { Img, OffthreadVideo, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import type { Clip, Crop, Shot } from "./shots";
import type { StyleSpec } from "./styles";

// Apple iPhone 18 Pro Max bezel PNG: 1470 x 3000 with a transparent 1320 x 2868 screen opening at (75, 66).
const BEZEL = { w: 1470, h: 3000, screenX: 75, screenY: 66, screenW: 1320, screenH: 2868, screenRadius: 222 };
const CLOSE_RADIUS = 56;
const PUSH_IN = 0.08;

const Video: React.FC<{ clip: Clip; style: React.CSSProperties }> = ({ clip, style }) =>
  <OffthreadVideo src={staticFile(`sources/${clip.file}`)} playbackRate={clip.rate} muted style={style} />;

/** The recording under Apple's unmodified bezel. Scale is fixed per style; the bezel never moves or gets effects. */
export const Device: React.FC<{ clip: Clip; spec: StyleSpec }> = ({ clip, spec }) => {
  const s = spec.deviceScale;
  const width = BEZEL.w * s;
  return <div style={{ position: "absolute", left: (1080 - width) / 2, top: spec.mediaTop, width, height: BEZEL.h * s }}>
    <Video clip={clip} style={{ position: "absolute", left: BEZEL.screenX * s, top: BEZEL.screenY * s, width: BEZEL.screenW * s, height: BEZEL.screenH * s, borderRadius: BEZEL.screenRadius * s }} />
    <Img src={staticFile("bezel.png")} style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
  </div>;
};

function fit(crop: Crop, max: { w: number; h: number }) {
  const scale = Math.min(max.w / crop.w, max.h / crop.h);
  return { scale, w: crop.w * scale, h: crop.h * scale };
}

/** A bezel-free crop of the recording. Only here may the slow push-in apply. */
export const CloseUp: React.FC<{ clip: Clip; crop: Crop; spec: StyleSpec; duration: number }> = ({ clip, crop, spec, duration }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { scale, w, h } = fit(crop, spec.mediaMax);
  const push = spec.pushIn ? 1 + PUSH_IN * Math.min(1, frame / (duration * fps)) : 1;
  return <div style={{ position: "absolute", left: (1080 - w) / 2, top: spec.closeTop, width: w, height: h, borderRadius: CLOSE_RADIUS, overflow: "hidden" }}>
    <div style={{ position: "absolute", inset: 0, transform: `scale(${push})` }}>
      <Video clip={clip} style={{ position: "absolute", left: -crop.x * scale, top: -crop.y * scale, width: clip.width * scale, height: clip.height * scale }} />
    </div>
  </div>;
};

export const ShotMedia: React.FC<{ shot: Shot; spec: StyleSpec }> = ({ shot, spec }) => {
  if (shot.kind === "device") return <Device clip={shot.clip} spec={spec} />;
  if (shot.kind === "close") return <CloseUp clip={shot.clip} crop={shot.crop} spec={spec} duration={shot.end - shot.start} />;
  return null;
};
