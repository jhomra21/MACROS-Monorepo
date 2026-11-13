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
// Phone slides: the headline block starts at y 290, about 70 px under the marker's baseline (y 233). The bezel starts about 52 px
// under the tallest two-line headline (ink to y 507), and its scale is the largest that ends 24 px above the bottom edge: (1920 - 24 - 560) / 3000.
const PHONE_HEADLINE_TOP = 290;
const PHONE_TOP = 560;
const PHONE_SCALE = 0.4453;

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
      <div style={slide.screenshot ? { ...column, top: PHONE_HEADLINE_TOP } : { ...column, top: 300, height: 1020, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <div style={{ fontSize: HEADLINE_SIZE[copy], fontWeight: 700, letterSpacing: "-0.03em", lineHeight: 1.08, textWrap: "balance" }}>{headline}</div>
      </div>
      {slide.screenshot && <Phone top={PHONE_TOP} scale={PHONE_SCALE}><Img src={staticFile(`screens/${slide.screenshot}.png`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} /></Phone>}
    </>}
    {isEnd && <EndSlide intro={slide.intro} />}
    {safeZones && <Zones />}
  </AbsoluteFill>;
};
