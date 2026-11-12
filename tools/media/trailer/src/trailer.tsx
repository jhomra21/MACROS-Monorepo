import React from "react";
import { AbsoluteFill, Audio, Sequence, staticFile, useVideoConfig } from "remotion";
import { EndCard } from "./end-card";
import { fontFamily } from "./font";
import { Device } from "./media";
import { SHOTS, type Shot, type Variant } from "./shots";
import { TextBlock } from "./text";
import { Backdrop, CoverDisc } from "./transitions";

export type Props = { variant: Variant; safeZones: boolean };

const SafeOverlay: React.FC = () => <AbsoluteFill style={{ pointerEvents: "none" }}>
  <div style={{ position: "absolute", left: 120, top: 380, width: 840, height: 1060, border: "2px solid #fff8" }} />
  {[{ x: 120, y: 250, w: 840, h: 1350 }, { x: 120, y: 160, w: 840, h: 1280 }, { x: 60, y: 380, w: 900, h: 1160 }].map((r, i) =>
    <div key={i} style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h, border: `2px dashed ${["#ff5d5d", "#58d68d", "#5dade2"][i]}` }} />)}
</AbsoluteFill>;

const ShotView: React.FC<{ shot: Shot; variant: Variant }> = ({ shot, variant }) =>
  shot.kind === "end" ? <EndCard variant={variant} /> : <TextBlock shot={shot} />;

// Back to front: colour field, phone, the colour covering the phone when the next shot has none, then every shot's text.
export const Trailer: React.FC<Props> = ({ variant, safeZones }) => {
  const { fps } = useVideoConfig();
  return <AbsoluteFill style={{ backgroundColor: "#0A0A0C", fontFamily, overflow: "hidden" }}>
    <Backdrop />
    <Device />
    <CoverDisc />
    {SHOTS.map((shot) => <Sequence key={shot.start} from={shot.start * fps} durationInFrames={(shot.end - shot.start) * fps}>
      <ShotView shot={shot} variant={variant} />
    </Sequence>)}
    {safeZones && <SafeOverlay />}
    <Audio src={staticFile("silence.wav")} volume={0} />
  </AbsoluteFill>;
};
