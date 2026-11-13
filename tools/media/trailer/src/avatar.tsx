import React from "react";
import { AbsoluteFill } from "remotion";
import { RINGS_VISIBLE_DIAMETER, RingsMark } from "./rings-mark";

const WIDTH_SHARE = 0.62;

/** 1080 x 1080 profile picture: the rings on white, no tile, as wide as 62% of the canvas. */
export const Avatar: React.FC = () =>
  <AbsoluteFill style={{ background: "#FFFFFF", alignItems: "center", justifyContent: "center" }}>
    <RingsMark tile={false} scale={(1080 * WIDTH_SHARE) / RINGS_VISIBLE_DIAMETER} />
  </AbsoluteFill>;
