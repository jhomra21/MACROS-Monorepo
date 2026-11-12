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

const WORD_REVEAL_SECONDS = 0.3;
const exitEase = Easing.bezier(0.4, 0, 0.2, 1);

const Word: React.FC<{ at: number; children: string }> = ({ at, children }) => {
  const p = useReveal(at, WORD_REVEAL_SECONDS);
  return <span style={{ opacity: p, transform: `translateY(${16 * (1 - p)}px)` }}>{children}</span>;
};

/** Fades out and drifts up over the `exitSeconds` before `at` seconds into the shot; without `at` it stays put. */
const Exit: React.FC<{ at?: number; style?: React.CSSProperties; children: React.ReactNode }> = ({ at, style, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = at === undefined ? 0 : interpolate(frame, [(at - STYLE.exitSeconds) * fps, at * fps], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: exitEase });
  return <div style={{ ...style, opacity: 1 - p, transform: `translateY(${-STYLE.exitDrift * p}px)` }}>{children}</div>;
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

const Headline: React.FC<{ phase: Phase; exitAt?: number }> = ({ phase, exitAt }) =>
  <Exit at={exitAt} style={{ display: "flex", flexWrap: "wrap", columnGap: "0.24em", justifyContent: "center", fontSize: STYLE.headSize, fontWeight: 700, letterSpacing: "-0.03em", lineHeight: 0.98 }}>
    {phase.words.map((word, i) => <Word key={word + i} at={phase.at + i * STYLE.wordStep}>{word}</Word>)}
  </Exit>;

/** When a phase leaves: the shot's end for the last one, the next phase's start for a phase that holds at least a second. Quick swaps just replace. */
function exitTime(phases: Phase[], phase: Phase, shotSeconds: number): number | undefined {
  const next = phases[phases.indexOf(phase) + 1];
  if (!next) return shotSeconds;
  return next.at - phase.at >= 1 ? next.at : undefined;
}

const column: React.CSSProperties = { position: "absolute", left: STYLE.column.left, width: STYLE.column.width, textAlign: "center" };

/** Headline, support line and counter at fixed positions inside x 120-960. */
export const TextBlock: React.FC<{ shot: Shot }> = ({ shot }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const phase = activePhase(shot.phases, frame / fps);
  const shotSeconds = shot.end - shot.start;
  const isType = shot.kind === "type";
  const headBox: React.CSSProperties = isType
    ? { top: 380, height: 1060, alignItems: "center" }
    : { top: STYLE.headTop, height: STYLE.headHeight, alignItems: "flex-end" };
  return <div style={{ color: STYLE.text, fontFamily }}>
    <div style={{ ...column, ...headBox, display: "flex", justifyContent: "center" }}>{phase && <Headline key={phase.at} phase={phase} exitAt={exitTime(shot.phases, phase, shotSeconds)} />}</div>
    {shot.support && <Exit at={shotSeconds} style={{ ...column, top: STYLE.supportTop }}>
      <Reveal at={0.5} style={{ fontSize: STYLE.supportSize, fontWeight: 500, lineHeight: 1.15 }}>{shot.support}</Reveal>
    </Exit>}
    {shot.counters.map((c) => <Exit key={c.label} at={shotSeconds} style={{ ...column, top: STYLE.counterTop }}><CounterView counter={c} /></Exit>)}
  </div>;
};
