import React from "react";
import { Easing, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { fontFamily } from "./font";
import type { Counter, Phase, Shot } from "./shots";
import type { StyleSpec } from "./styles";

const REVEAL_SECONDS = 0.35;
const ease = Easing.bezier(0.2, 0.8, 0.2, 1);

/** 0 to 1 over 0.35 s starting at `at` seconds into the shot. */
export function useReveal(at: number, seconds = REVEAL_SECONDS): number {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return interpolate(frame, [at * fps, (at + seconds) * fps], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: ease });
}

export const Reveal: React.FC<{ at: number; rise?: number; style?: React.CSSProperties; children: React.ReactNode }> = ({ at, rise = 16, style, children }) => {
  const p = useReveal(at);
  return <div style={{ ...style, opacity: p, transform: `translateY(${rise * (1 - p)}px)` }}>{children}</div>;
};

const Word: React.FC<{ at: number; children: string }> = ({ at, children }) => {
  const p = useReveal(at);
  return <span style={{ opacity: p, transform: `translateY(${16 * (1 - p)}px)` }}>{children}</span>;
};

function activePhase(phases: Phase[], seconds: number): Phase | undefined {
  return phases.filter((p) => p.at <= seconds).at(-1);
}

const CounterView: React.FC<{ counter: Counter; style: StyleSpec }> = ({ counter, style }) => {
  const progress = useReveal(counter.at, counter.duration);
  const value = counter.from + (counter.to - counter.from) * progress;
  return <div style={{ display: "flex", alignItems: "baseline", gap: 20 }}>
    <span style={{ fontSize: 110, fontWeight: 700, letterSpacing: "-0.03em", fontVariantNumeric: "tabular-nums", color: style.text }}>{value.toFixed(counter.decimals ?? 0)}</span>
    <span style={{ fontSize: 44, fontWeight: 500, color: style.muted }}>{counter.label}</span>
  </div>;
};

/** Headline, support line and counters in one column inside x 120-960. */
export const TextBlock: React.FC<{ shot: Shot; style: StyleSpec }> = ({ shot, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const phase = activePhase(shot.phases, frame / fps);
  const isType = shot.kind === "type";
  const size = isType ? style.typeSize : style.headSize;
  return <div style={{ position: "absolute", left: 120, width: 840, top: isType ? 760 : 380, textAlign: style.align, color: style.text, fontFamily }}>
    {phase && <div key={phase.at} style={{ display: "flex", flexWrap: "wrap", columnGap: "0.24em", justifyContent: style.align === "center" ? "center" : "flex-start", fontSize: size, fontWeight: 700, letterSpacing: "-0.03em", lineHeight: 0.98 }}>
      {phase.words.map((word, i) => <Word key={word + i} at={phase.at + i * style.wordStep}>{word}</Word>)}
    </div>}
    {shot.support && <Reveal at={0.5} style={{ marginTop: 28, fontSize: 56, fontWeight: 500, color: style.muted, lineHeight: 1.15 }}>{shot.support}</Reveal>}
    {style.counters && shot.counters.length > 0 && <div style={{ marginTop: 20, display: "flex", flexWrap: "wrap", columnGap: 48 }}>
      {shot.counters.map((c) => <CounterView key={c.label} counter={c} style={style} />)}
    </div>}
  </div>;
};
