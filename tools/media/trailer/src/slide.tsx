import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";
import { fontFamily } from "./font";
import { BEZEL, Phone } from "./media";
import { RingsMark } from "./rings-mark";
import { CTA, SETS, SITE, type Copy } from "./slides";
import { STYLE } from "./styles";

export type Format = "tiktok" | "instagram";

export type SlideProps = { format: Format; set: number; index: number; safeZones: boolean; copy: Copy };

const LINE_HEIGHT = 1.08;

const columnAt = (left: number, width: number): React.CSSProperties => ({ position: "absolute", left, width, textAlign: "center" });

// TikTok photo mode draws its own UI over PHOTO_MODE_OVERLAYS. Text and the phone stay inside this box (see docs/evidence/tiktok-slides/README.md).
const SAFE = { top: 200, bottom: 1480, left: 120, right: 940 };

// One size per variant, the largest that keeps every headline within its line limit (see docs/evidence/tiktok-slides/README.md).
const HEADLINE_SIZE: Record<Copy, number> = { short: 100, full: 105 };

// Phone slides: the headline block starts at y 210 and the tallest two-line headline's last ink row is 428. The bezel starts 40 px
// under that ink, at y 469, and its scale fills the rest of the safe area: (1480 - 469) / 3000 = 0.337.
const PHONE_HEADLINE_TOP = 210;

const PHONE_TOP = 469;

const PHONE_SCALE = (SAFE.bottom - PHONE_TOP) / BEZEL.h;

// Instagram 4:5. The marker row is y 60-130 and the headline starts 50 px under it. One size fits every short headline in two lines
// within x 90-990 (see docs/evidence/instagram-slides/README.md). The bezel starts 40 px under the tallest two-line headline and ends
// 24 px above the bottom edge, so it is as large as the canvas allows under the headline.
const IG_HEADLINE_SIZE = 110;

const IG_HEADLINE_TOP = 180;

// The ink of a two-line headline ends about 2 px under its line box, so 44 px under the box leaves 40 px of clear space above the bezel.
const IG_PHONE_TOP = IG_HEADLINE_TOP + 2 * IG_HEADLINE_SIZE * LINE_HEIGHT + 44;

const IG_PHONE_SCALE = (1350 - 24 - IG_PHONE_TOP) / BEZEL.h;

type Layout = {
  height: number;
  box: React.CSSProperties;
  marker?: { top: number; height: number; icon: number };
  headline: { top: number; size: Record<Copy, number> };
  typeBox: { top: number; height: number };
  endBox: { top: number; height: number };
  phone: { top: number; scale: number };
};

export const LAYOUT: Record<Format, Layout> = {
  tiktok: {
    height: 1920,
    box: columnAt(SAFE.left, SAFE.right - SAFE.left),
    headline: { top: PHONE_HEADLINE_TOP, size: HEADLINE_SIZE },
    typeBox: { top: SAFE.top, height: SAFE.bottom - SAFE.top },
    endBox: { top: SAFE.top, height: SAFE.bottom - SAFE.top },
    phone: { top: PHONE_TOP, scale: PHONE_SCALE },
  },
  instagram: {
    height: 1350,
    box: columnAt(90, 900),
    marker: { top: 60, height: 70, icon: 0.27 },
    headline: { top: IG_HEADLINE_TOP, size: { short: IG_HEADLINE_SIZE, full: IG_HEADLINE_SIZE } },
    typeBox: { top: 130, height: 1160 },
    endBox: { top: 130, height: 1160 },
    phone: { top: IG_PHONE_TOP, scale: IG_PHONE_SCALE },
  },
};

/** TikTok's photo-mode overlays on the 1080 x 1920 canvas (left, top, width, height). The review copies outline them. */
const PHOTO_MODE_OVERLAYS: React.CSSProperties[] = [
  { left: 0, top: 0, width: 1080, height: 110 }, // search bar and TikTok's own counter
  { left: 960, top: 150, width: 100, height: 40 }, // TikTok's "1/5" pill
  { left: 0, top: 1515, width: 1080, height: 405 }, // caption and comment panel
  { left: 950, top: 1000, width: 130, height: 920 }, // like, comment and share column
];

const Zones: React.FC = () => <>
  {PHOTO_MODE_OVERLAYS.map((rect, i) => <div key={i} style={{ ...rect, position: "absolute", background: "rgba(255,0,0,0.25)", outline: "4px solid #FF0000" }} />)}
</>;

const EndSlide: React.FC<{ box: React.CSSProperties; intro?: string }> = ({ box, intro }) =>
  <div style={{ ...box, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
    <div style={{ marginBottom: 55 }}><RingsMark /></div>
    <div style={{ fontSize: 144, fontWeight: 700, letterSpacing: "-0.04em", lineHeight: 1 }}>MACROS</div>
    {intro && <div style={{ marginTop: 60, fontSize: 45, fontWeight: 500 }}>{intro}</div>}
    <div style={{ marginTop: intro ? 20 : 60, fontSize: 53, fontWeight: 500, lineHeight: 1.15, maxWidth: 700 }}>{CTA}</div>
    <div style={{ marginTop: 60, fontSize: 41, fontWeight: 500 }}>{SITE}</div>
  </div>;

export const Slide: React.FC<SlideProps> = ({ format, set, index, safeZones, copy }) => {
  const layout = LAYOUT[format];
  const { slides } = SETS[set - 1];
  const slide = slides[index - 1];
  const isEnd = index === slides.length;
  const headline = copy === "short" ? slide.short ?? slide.headline : slide.headline;

  return <AbsoluteFill style={{ background: slide.color, color: STYLE.text, fontFamily }}>
    {layout.marker && <div style={{ ...layout.box, top: layout.marker.top, height: layout.marker.height, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
      <div>{index === 1 && <RingsMark scale={layout.marker.icon} />}</div>
      <div style={{ fontSize: 40, fontWeight: 500, fontVariantNumeric: "tabular-nums" }}>{index}/{slides.length}</div>
    </div>}
    {!isEnd && <>
      <div style={slide.screenshot ? { ...layout.box, top: layout.headline.top } : { ...layout.box, top: layout.typeBox.top, height: layout.typeBox.height, display: "flex", alignItems: "center", justifyContent: "center" }}>
        <div style={{ fontSize: layout.headline.size[copy], fontWeight: 700, letterSpacing: "-0.03em", lineHeight: LINE_HEIGHT, textWrap: "balance" }}>{headline}</div>
      </div>
      {slide.screenshot && <Phone top={layout.phone.top} scale={layout.phone.scale}><Img src={staticFile(`screens/${slide.screenshot}.png`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} /></Phone>}
    </>}
    {isEnd && <EndSlide box={{ ...layout.box, top: layout.endBox.top, height: layout.endBox.height }} intro={slide.intro} />}
    {safeZones && <Zones />}
  </AbsoluteFill>;
};
