import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";
import { fontFamily } from "./font";
import { Phone } from "./media";
import { RingsMark } from "./rings-mark";
import { CTA, SETS, SITE, type Copy } from "./slides";
import { STYLE } from "./styles";

export type SlideProps = { set: number; index: number; safeZones: boolean; copy: Copy };

// TikTok keeps its own UI over the top 150 px, bottom 380 px and right 140 px; text stays inside x 120-940.
const SAFE = { top: 150, bottom: 380, right: 140, left: 120 };
// One size per variant, the largest that keeps every headline within its line limit (see docs/evidence/tiktok-slides/README.md).
const HEADLINE_SIZE: Record<Copy, number> = { short: 100, full: 105 };
const column: React.CSSProperties = { position: "absolute", left: SAFE.left, width: 1080 - SAFE.right - SAFE.left, textAlign: "center" };

const Zones: React.FC = () => {
  const zone: React.CSSProperties = { position: "absolute", background: "rgba(255,0,0,0.25)", outline: "4px solid #FF0000" };
  return <>
    <div style={{ ...zone, left: 0, top: 0, width: 1080, height: SAFE.top }} />
    <div style={{ ...zone, left: 0, top: 1920 - SAFE.bottom, width: 1080, height: SAFE.bottom }} />
    <div style={{ ...zone, left: 1080 - SAFE.right, top: SAFE.top, width: SAFE.right, height: 1920 - SAFE.top - SAFE.bottom }} />
  </>;
};

const EndSlide: React.FC<{ intro?: string }> = ({ intro }) =>
  <div style={{ ...column, top: SAFE.top, height: 1920 - SAFE.top - SAFE.bottom, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
    <div style={{ marginBottom: 55 }}><RingsMark /></div>
    <div style={{ fontSize: 144, fontWeight: 700, letterSpacing: "-0.04em", lineHeight: 1 }}>MACROS</div>
    {intro && <div style={{ marginTop: 60, fontSize: 45, fontWeight: 500 }}>{intro}</div>}
    <div style={{ marginTop: intro ? 20 : 60, fontSize: 53, fontWeight: 500, lineHeight: 1.15, maxWidth: 700 }}>{CTA}</div>
    <div style={{ marginTop: 60, fontSize: 41, fontWeight: 500 }}>{SITE}</div>
  </div>;

export const Slide: React.FC<SlideProps> = ({ set, index, safeZones, copy }) => {
  const { slides } = SETS[set - 1];
  const slide = slides[index - 1];
  const isEnd = index === slides.length;
  const headline = copy === "short" ? slide.short ?? slide.headline : slide.headline;
  return <AbsoluteFill style={{ background: slide.color, color: STYLE.text, fontFamily }}>
    <div style={{ ...column, top: 170, height: 90, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
      <div>{index === 1 && <RingsMark scale={0.34} />}</div>
      <div style={{ fontSize: 40, fontWeight: 500, fontVariantNumeric: "tabular-nums" }}>{index}/{slides.length}</div>
    </div>
    {!isEnd && <>
      <div style={{ ...column, top: 300, height: slide.screenshot ? 540 : 1020, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <div style={{ fontSize: HEADLINE_SIZE[copy], fontWeight: 700, letterSpacing: "-0.03em", lineHeight: 1.08, textWrap: "balance" }}>{headline}</div>
      </div>
      {slide.screenshot && <Phone><Img src={staticFile(`screens/${slide.screenshot}.png`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} /></Phone>}
      {slide.demo && <div style={{ position: "absolute", left: SAFE.left, top: STYLE.deviceTop + 120, width: 150, fontSize: 30, fontWeight: 500, lineHeight: 1.2 }}>Demo data</div>}
    </>}
    {isEnd && <EndSlide intro={slide.intro} />}
    {safeZones && <Zones />}
  </AbsoluteFill>;
};
