import React from "react";
import { AbsoluteFill, Audio, Sequence, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { EndCard } from "./end-card";
import { fontFamily } from "./font";
import { ShotMedia } from "./media";
import { SHOTS, type Shot, type Style, type Variant } from "./shots";
import { STYLES, type StyleSpec } from "./styles";
import { TextBlock } from "./text";

export type Props = { style: Style; variant: Variant; safeZones: boolean };

/** Solid colour field (bold) or near-black with a slowly drifting colour wash (restrained). */
const Background: React.FC<{ shot: Shot; spec: StyleSpec }> = ({ shot, spec }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  if (!spec.background) return <AbsoluteFill style={{ background: shot.color }} />;
  const drift = interpolate(frame, [0, durationInFrames], [42, 58]);
  return <AbsoluteFill style={{ background: `radial-gradient(ellipse 90% 60% at 50% ${drift}%, ${shot.color}80 0%, ${shot.color}33 45%, ${spec.background} 100%)` }} />;
};

const SafeOverlay: React.FC = () => <AbsoluteFill style={{ pointerEvents: "none" }}>
  <div style={{ position: "absolute", left: 120, top: 380, width: 840, height: 1060, border: "2px solid #fff8" }} />
  {[{ x: 120, y: 250, w: 840, h: 1350 }, { x: 120, y: 160, w: 840, h: 1280 }, { x: 60, y: 380, w: 900, h: 1160 }].map((r, i) =>
    <div key={i} style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h, border: `2px dashed ${["#ff5d5d", "#58d68d", "#5dade2"][i]}` }} />)}
</AbsoluteFill>;

const ShotView: React.FC<{ shot: Shot; spec: StyleSpec; variant: Variant }> = ({ shot, spec, variant }) =>
  <AbsoluteFill>
    <Background shot={shot} spec={spec} />
    <ShotMedia shot={shot} spec={spec} />
    {shot.kind === "end" ? <EndCard variant={variant} spec={spec} /> : <TextBlock shot={shot} style={spec} />}
  </AbsoluteFill>;

export const Trailer: React.FC<Props> = ({ style, variant, safeZones }) => {
  const { fps } = useVideoConfig();
  const spec = STYLES[style];
  return <AbsoluteFill style={{ backgroundColor: "#0A0A0C", fontFamily, overflow: "hidden" }}>
    {SHOTS.map((shot) => <Sequence key={shot.start} from={shot.start * fps} durationInFrames={(shot.end - shot.start) * fps}>
      <ShotView shot={shot} spec={spec} variant={variant} />
    </Sequence>)}
    {safeZones && <SafeOverlay />}
    <Audio src={staticFile("silence.wav")} volume={0} />
  </AbsoluteFill>;
};
