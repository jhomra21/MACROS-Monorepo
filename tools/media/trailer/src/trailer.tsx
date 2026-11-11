import React from "react";
import { AbsoluteFill, Audio, Img, OffthreadVideo, Sequence, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { loadFont } from "@remotion/google-fonts/Inter";

const { fontFamily } = loadFont("normal", { weights: ["500", "700"], subsets: ["latin"] });
type Props = { variant: "coming-soon" | "app-store"; safeZones: boolean };
type Shot = { start: number; end: number; source: string; from: number; to: number; rate: number; layout: "close" | "device" | "widget" | "type" | "end"; headline: string; support: string };
const shots: Shot[] = [
  { start: 0, end: 2, source: "raw.mp4", from: 0, to: 2, rate: 1, layout: "close", headline: "Log your food.", support: "" },
  { start: 2, end: 8, source: "a1-log.mov", from: 7, to: 13, rate: 1, layout: "device", headline: "Search it.", support: "Type it, tap it, done." },
  { start: 8, end: 14, source: "scan-review.png", from: 0, to: 6, rate: 1, layout: "device", headline: "Scan it.", support: "Barcodes and nutrition labels." },
  { start: 14, end: 17, source: "a1-log.mov", from: 18, to: 21, rate: 1, layout: "close", headline: "Rings fill as you go.", support: "" },
  { start: 17, end: 21, source: "b2-insights.mov", from: 2, to: 6, rate: 1, layout: "device", headline: "Track it.", support: "Weight and calories, over time." },
  { start: 21, end: 25, source: "widgets-only.mp4", from: 0, to: 4, rate: 1, layout: "widget", headline: "Glance at it.", support: "Home Screen widgets." },
  { start: 25, end: 27, source: "raw.mp4", from: 66, to: 68, rate: 1, layout: "type", headline: "Search.  Scan.  Track.  Done.", support: "" },
  { start: 27, end: 30, source: "raw.mp4", from: 70, to: 73, rate: 1, layout: "end", headline: "MACROS", support: "" },
];
// Apple iPhone 18 Pro Max bezel PNG: 1470x3000 with a transparent 1320x2868 screen opening at (75, 66).
const BEZEL = { w: 1470, h: 3000, screenX: 75, screenY: 66, screenW: 1320, screenH: 2868 };
const BEZEL_SCALE = 0.36;
const DEVICE = { left: (1080 - BEZEL.w * BEZEL_SCALE) / 2, top: 650 };
const wash = ["#007AFF", "#FF9F0A", "#EF4F87"];

const FadeText: React.FC<{ text: string; size: number; top: number; frame: number }> = ({ text, size, top, frame }) => {
  const p = Math.min(1, frame / 10);
  const eased = 1 - Math.pow(1 - p, 3);
  return <div style={{ position: "absolute", top, width: "100%", textAlign: "center", color: "white", fontFamily, fontWeight: 700, letterSpacing: "-0.03em", fontSize: size, whiteSpace: "nowrap", opacity: eased, transform: `translateY(${16 * (1 - eased)}px)` }}>{text}</div>;
};

const SafeOverlay: React.FC = () => <AbsoluteFill style={{ pointerEvents: "none" }}>
  <div style={{ position: "absolute", left: 120, top: 380, width: 840, height: 1060, border: "2px solid #fff8" }} />
  {[{ x: 120, y: 250, w: 840, h: 1350 }, { x: 120, y: 160, w: 840, h: 1280 }, { x: 60, y: 380, w: 900, h: 1160 }].map((r, i) => <div key={i} style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h, border: `2px dashed ${["#ff5d5d", "#58d68d", "#5dade2"][i]}` }} />)}
</AbsoluteFill>;

// The recording sits under the unmodified bezel; the bezel never moves, scales per frame, or gets effects.
const Device: React.FC<{ shot: Shot; fps: number }> = ({ shot, fps }) => {
  const screen = { position: "absolute", left: BEZEL.screenX * BEZEL_SCALE, top: BEZEL.screenY * BEZEL_SCALE, width: BEZEL.screenW * BEZEL_SCALE, height: BEZEL.screenH * BEZEL_SCALE, borderRadius: 80 } as const;
  return <div style={{ position: "absolute", left: DEVICE.left, top: DEVICE.top, width: BEZEL.w * BEZEL_SCALE, height: BEZEL.h * BEZEL_SCALE }}>
    {shot.source.endsWith(".png")
      ? <Img src={staticFile(`sources/${shot.source}`)} style={screen} />
      : <OffthreadVideo src={staticFile(`sources/${shot.source}`)} startFrom={Math.round(shot.from * fps)} endAt={Math.round(shot.to * fps)} playbackRate={shot.rate} style={screen} />}
    <Img src={staticFile("bezel.png")} style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
  </div>;
};

export const Trailer: React.FC<Props> = ({ variant, safeZones }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const shot = shots.find((s) => frame >= s.start * fps && frame < s.end * fps)!;
  const localFrame = frame - shot.start * fps;
  const reveal = (after: number) => Math.max(0, Math.min(1, (localFrame - after) / 10));
  const headline = shot.start === 0
    ? localFrame < fps ? "Log your food." : "Get on with your day."
    : shot.start === 25
      ? ["Search.", "Scan.", "Track.", "Done."][Math.floor(localFrame / 15)]
      : shot.headline;
  const isEnd = shot.layout === "end";
  const appIcon = staticFile("app-icon.png");
  return <AbsoluteFill style={{ backgroundColor: "#0A0A0C", color: "white", fontFamily, overflow: "hidden" }}>
    <AbsoluteFill style={{ background: `radial-gradient(ellipse at 50% 52%, ${wash[Math.floor(shot.start / 7) % 3]}30 0%, transparent 70%)` }} />
    {shots.map((s) => s.layout === "type" || s.layout === "end" ? null : <Sequence key={s.start} from={s.start * fps} durationInFrames={(s.end - s.start) * fps}>
      {s.layout === "device" ? <Device shot={s} fps={fps} /> : <OffthreadVideo src={staticFile(`sources/${s.source}`)} startFrom={Math.round(s.from * fps)} endAt={Math.round(s.to * fps)} playbackRate={s.rate}
        style={s.layout === "widget" ? { position: "absolute", width: 840, height: 407, left: 120, top: 780, borderRadius: 56 } : { position: "absolute", width: 1040, height: 1100, objectFit: "cover", objectPosition: "top", left: 20, top: 650, borderRadius: 56 }} />}
    </Sequence>)}
    {!isEnd && <FadeText text={headline} size={headline.length > 14 ? 84 : 128} top={420} frame={shot.layout === "type" ? localFrame % 15 : localFrame} />}
    {!isEnd && shot.support && <div style={{ position: "absolute", top: 575, width: "100%", textAlign: "center", color: "#A1A1A6", fontSize: 48, fontWeight: 500 }}>{shot.support}</div>}
    {isEnd && <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", background: "#0A0A0C" }}>
      <Img src={appIcon} style={{ width: 260, height: 260, borderRadius: 58, marginBottom: 55, opacity: reveal(0) }} />
      <div style={{ fontSize: 120, fontWeight: 700, letterSpacing: "-0.04em", opacity: reveal(15) }}>MACROS</div>
      {variant === "coming-soon"
        ? <div style={{ marginTop: 38, color: "#A1A1A6", fontSize: 48, opacity: reveal(30) }}>Coming soon to iPhone</div>
        : <Img src={staticFile("app-store-badge.svg")} style={{ marginTop: 44, width: 240, opacity: reveal(30) }} />}
      <div style={{ position: "absolute", bottom: 500, color: "#A1A1A6", fontSize: 32, opacity: reveal(60) }}>macrosios.com</div>
    </AbsoluteFill>}
    {safeZones && <SafeOverlay />}
    <Audio src={staticFile("silence.wav")} volume={0} />
  </AbsoluteFill>;
};
