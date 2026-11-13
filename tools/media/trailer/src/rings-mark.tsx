import React from "react";
import { COLORS } from "./shots";
import { useReveal } from "./text";

/**
 * The MACROS rings mark, drawn at the Today ring's proportions from `MacroRingSetView`: the line width is 8% of the outer
 * diameter, each inner ring steps in by one line width less 0.4% (the app's overlap), and the track is the palette's track
 * colour at 45% opacity. Protein is outermost, then carbs, then fat. The app's Today ring is 269 pt; this is scaled to 176 px.
 */
const TILE = 260;
const OUTER_DIAMETER = 176;
const LINE_WIDTH = OUTER_DIAMETER * 0.08;
const OVERLAP = OUTER_DIAMETER * 0.004;
const TRACK_OPACITY = 0.45;
const SWEEP_SECONDS = 0.6;

const radius = (index: number) => (OUTER_DIAMETER - index * (LINE_WIDTH * 2 - OVERLAP)) / 2;

const RINGS = [
  { progress: 0.75, color: COLORS.protein, track: "rgb(158,191,237)" },
  { progress: 0.85, color: COLORS.carbs, track: "rgb(214,158,61)" },
  { progress: 0.65, color: COLORS.fat, track: "rgb(214,122,158)" },
] as const;

/** The rings drawn from the outer ring's outer edge: 2 x (radius + half the line width). */
export const RINGS_VISIBLE_DIAMETER = OUTER_DIAMETER + LINE_WIDTH;

/** A white rounded tile (iOS icon proportions) holding the rings; they sweep from 0 to their progress as the tile appears. Without a tile the rings sit on whatever is behind. `scale` resizes the whole mark. */
export const RingsMark: React.FC<{ tile?: boolean; scale?: number }> = ({ tile = true, scale = 1 }) => {
  const sweep = useReveal(0, SWEEP_SECONDS);
  const centre = TILE / 2;
  return <div style={{ width: TILE * scale, height: TILE * scale }}><div style={{ width: TILE, height: TILE, transform: `scale(${scale})`, transformOrigin: "0 0", borderRadius: TILE * 0.225, background: tile ? "#FFFFFF" : "transparent" }}>
    <svg width={TILE} height={TILE} viewBox={`0 0 ${TILE} ${TILE}`} style={{ display: "block" }}>
      {RINGS.map((ring, index) => {
        const circle = { cx: centre, cy: centre, r: radius(index), fill: "none", strokeWidth: LINE_WIDTH };
        return <g key={ring.color} transform={`rotate(-90 ${centre} ${centre})`}>
          <circle {...circle} stroke={ring.track} strokeOpacity={TRACK_OPACITY} />
          {sweep > 0 && <circle {...circle} pathLength={100} stroke={ring.color} strokeLinecap="round"
            strokeDasharray={`${ring.progress * sweep * 100} 100`} />}
        </g>;
      })}
    </svg>
  </div></div>;
};
