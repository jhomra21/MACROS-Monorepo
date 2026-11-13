import React from "react";
import { AbsoluteFill, Freeze, Img, OffthreadVideo, Sequence, staticFile, useCurrentFrame } from "remotion";
import { FPS, SHOTS, type DeviceShot } from "./shots";
import { STYLE } from "./styles";
import { before, screenFade } from "./transitions";

// Apple iPhone 18 Pro Max bezel PNG: 1470 x 3000 with a transparent 1320 x 2868 screen opening at (75, 66).
const BEZEL = { w: 1470, h: 3000, screenX: 75, screenY: 66, screenW: 1320, screenH: 2868, screenRadius: 222 };

const deviceShots = SHOTS.filter((shot): shot is DeviceShot => shot.kind === "device");
const lastEnd = deviceShots[deviceShots.length - 1].end * FPS;

/** One recording. Around a cut it rests on its first frame before and its last frame after, so the footage itself is never moved or stretched. */
const Screen: React.FC<{ shot: DeviceShot; fadesIn: boolean }> = ({ shot, fadesIn }) => {
  const frame = useCurrentFrame();
  const start = shot.start * FPS;
  const end = shot.end * FPS;
  const lead = before(STYLE.screenFrames);
  const video = <OffthreadVideo src={staticFile(`sources/${shot.clip.file}`)} playbackRate={shot.clip.rate} muted
    style={{ width: "100%", height: "100%", objectFit: "cover" }} />;
  return <AbsoluteFill style={{ opacity: fadesIn ? screenFade(frame, start) : 1 }}>
    {fadesIn && <Sequence from={start - lead} durationInFrames={lead}><Freeze frame={0}>{video}</Freeze></Sequence>}
    <Sequence from={start} durationInFrames={end - start}>{video}</Sequence>
    <Sequence from={end} durationInFrames={STYLE.screenFrames - lead}><Freeze frame={end - start - 1}>{video}</Freeze></Sequence>
  </AbsoluteFill>;
};

/**
 * Apple's unmodified bezel at a fixed size and place; it never moves, fades or gets effects. Each recording cross-fades over
 * the previous one inside the screen opening: the incoming screen fades in on top of the outgoing one, which stays opaque.
 * The phone ends at the last device shot's cut; after it only the colour disc is on screen.
 */
export const Phone: React.FC<{ children: React.ReactNode; top?: number; scale?: number }> = ({ children, top = STYLE.deviceTop, scale = STYLE.deviceScale }) => {
  const width = BEZEL.w * scale;
  return <div style={{ position: "absolute", left: (1080 - width) / 2, top, width, height: BEZEL.h * scale }}>
    <div style={{ position: "absolute", left: BEZEL.screenX * scale, top: BEZEL.screenY * scale, width: BEZEL.screenW * scale, height: BEZEL.screenH * scale, borderRadius: BEZEL.screenRadius * scale, overflow: "hidden", background: "#000" }}>
      {children}
    </div>
    <Img src={staticFile("bezel.png")} style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
  </div>;
};

export const Device: React.FC = () =>
  <Sequence from={0} durationInFrames={lastEnd} layout="none">
    <Phone>{deviceShots.map((shot, i) => <Screen key={shot.start} shot={shot} fadesIn={i > 0} />)}</Phone>
  </Sequence>;
