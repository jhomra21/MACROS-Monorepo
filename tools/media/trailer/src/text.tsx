import React from "react";
import { Easing, interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { fontFamily } from "./font";
import type { Counter, Phase, Shot } from "./shots";
import { STYLE } from "./styles";

const REVEAL_SECONDS = 0.35;
const ease = Easing.bezier(0.2, 0.8, 0.2, 1);

/** 0 to 1 over `seconds` starting at `at` seconds into the shot. */
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

const CounterView: React.FC<{ counter: Counter }> = ({ counter }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const progress = useReveal(counter.at, counter.duration);
  const moves = [counter, ...(counter.steps ?? [])];
  const value = moves.reduce((from, move) =>
    interpolate(frame, [move.at * fps, (move.at + move.duration) * fps], [from, move.to], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: ease }), counter.from);
  // Hidden until the count starts, so no counter ever rests on its starting value.
  return <div style={{ display: "flex", justifyContent: "center", alignItems: "baseline", gap: 16, opacity: progress > 0 ? 1 : 0 }}>
    <span style={{ fontSize: 72, fontWeight: 700, letterSpacing: "-0.03em", fontVariantNumeric: "tabular-nums" }}>{value.toFixed(counter.decimals ?? 0)}</span>
    <span style={{ fontSize: 36, fontWeight: 500 }}>{counter.label}</span>
  </div>;
};

const Headline: React.FC<{ phase: Phase }> = ({ phase }) =>
  <div key={phase.at} style={{ display: "flex", flexWrap: "wrap", columnGap: "0.24em", justifyContent: "center", fontSize: STYLE.headSize, fontWeight: 700, letterSpacing: "-0.03em", lineHeight: 0.98 }}>
    {phase.words.map((word, i) => <Word key={word + i} at={phase.at + i * STYLE.wordStep}>{word}</Word>)}
  </div>;

const column: React.CSSProperties = { position: "absolute", left: STYLE.column.left, width: STYLE.column.width, textAlign: "center" };

/** Headline, support line and counter at fixed positions inside x 120-960. */
export const TextBlock: React.FC<{ shot: Shot }> = ({ shot }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const phase = activePhase(shot.phases, frame / fps);
  const isType = shot.kind === "type";
  const headBox: React.CSSProperties = isType
    ? { top: 380, height: 1060, alignItems: "center" }
    : { top: STYLE.headTop, height: STYLE.headHeight, alignItems: "flex-end" };
  return <div style={{ color: STYLE.text, fontFamily }}>
    <div style={{ ...column, ...headBox, display: "flex", justifyContent: "center" }}>{phase && <Headline phase={phase} />}</div>
    {shot.support && <Reveal at={0.5} style={{ ...column, top: STYLE.supportTop, fontSize: STYLE.supportSize, fontWeight: 500, lineHeight: 1.15 }}>{shot.support}</Reveal>}
    {shot.counters.map((c) => <div key={c.label} style={{ ...column, top: STYLE.counterTop }}><CounterView counter={c} /></div>)}
  </div>;
};
