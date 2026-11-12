import React from "react";
import { Img, OffthreadVideo, staticFile } from "remotion";
import type { Clip } from "./shots";
import { STYLE } from "./styles";

// Apple iPhone 18 Pro Max bezel PNG: 1470 x 3000 with a transparent 1320 x 2868 screen opening at (75, 66).
const BEZEL = { w: 1470, h: 3000, screenX: 75, screenY: 66, screenW: 1320, screenH: 2868, screenRadius: 222 };

/** The recording under Apple's unmodified bezel. Scale and place are fixed; the bezel never moves or gets effects. */
export const Device: React.FC<{ clip: Clip }> = ({ clip }) => {
  const s = STYLE.deviceScale;
  const width = BEZEL.w * s;
  return <div style={{ position: "absolute", left: (1080 - width) / 2, top: STYLE.deviceTop, width, height: BEZEL.h * s }}>
    <OffthreadVideo src={staticFile(`sources/${clip.file}`)} playbackRate={clip.rate} muted
      style={{ position: "absolute", left: BEZEL.screenX * s, top: BEZEL.screenY * s, width: BEZEL.screenW * s, height: BEZEL.screenH * s, borderRadius: BEZEL.screenRadius * s, objectFit: "cover" }} />
    <Img src={staticFile("bezel.png")} style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />
  </div>;
};
