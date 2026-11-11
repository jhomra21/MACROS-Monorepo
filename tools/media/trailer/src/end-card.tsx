import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";
import { fontFamily } from "./font";
import type { Variant } from "./shots";
import type { StyleSpec } from "./styles";
import { Reveal } from "./text";

export const EndCard: React.FC<{ variant: Variant; spec: StyleSpec }> = ({ variant, spec }) =>
  <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", color: spec.text, fontFamily }}>
    <Reveal at={0}><Img src={staticFile("app-icon.png")} style={{ width: 260, height: 260, borderRadius: 58, marginBottom: 55 }} /></Reveal>
    <Reveal at={0.5} style={{ fontSize: 150, fontWeight: 700, letterSpacing: "-0.04em" }}>MACROS</Reveal>
    <Reveal at={1} style={{ marginTop: 38 }}>
      {variant === "coming-soon"
        ? <div style={{ color: spec.muted, fontSize: 56, fontWeight: 500 }}>Coming soon to iPhone</div>
        : <Img src={staticFile("app-store-badge.svg")} style={{ width: 240 }} />}
    </Reveal>
    <Reveal at={2} style={{ position: "absolute", top: 1330, color: spec.muted, fontSize: 40, fontWeight: 500 }}>macrosios.com</Reveal>
  </AbsoluteFill>;
