import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";
import { fontFamily } from "./font";
import { RingsMark } from "./rings-mark";
import type { Variant } from "./shots";
import { STYLE } from "./styles";
import { Reveal } from "./text";

export const EndCard: React.FC<{ variant: Variant }> = ({ variant }) =>
  <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", color: STYLE.text, fontFamily }}>
    <Reveal at={0} style={{ marginBottom: 55 }}><RingsMark /></Reveal>
    <Reveal at={0.5} style={{ fontSize: STYLE.headSize, fontWeight: 700, letterSpacing: "-0.04em" }}>MACROS</Reveal>
    <Reveal at={1} style={{ marginTop: 38 }}>
      {variant === "coming-soon"
        ? <div style={{ fontSize: 56, fontWeight: 500 }}>Coming soon to iPhone</div>
        : <Img src={staticFile("app-store-badge.svg")} style={{ width: 240 }} />}
    </Reveal>
    <Reveal at={2} style={{ position: "absolute", top: 1330, fontSize: 40, fontWeight: 500 }}>macrosios.com</Reveal>
  </AbsoluteFill>;
