import React from "react";
import { Composition } from "remotion";
import { Avatar } from "./avatar";
import { FPS, TOTAL_FRAMES } from "./shots";
import { LAYOUT, Slide, type SlideProps } from "./slide";
import { Trailer, type Props } from "./trailer";

// The rings mark sweeps in over its first 0.6 s; stills are taken at frame 30, after it settles.
const STILL_FRAMES = 31;
const defaultProps: Props = { variant: "coming-soon", safeZones: false };
const slideProps: SlideProps = { format: "tiktok", set: 1, index: 1, safeZones: false, copy: "short" };

export const Root: React.FC = () => (
  <>
    <Composition id="Trailer" component={Trailer} width={1080} height={1920} fps={FPS} durationInFrames={TOTAL_FRAMES} defaultProps={defaultProps} />
    <Composition id="Slide" component={Slide} width={1080} height={1920} fps={FPS} durationInFrames={STILL_FRAMES} defaultProps={slideProps}
      calculateMetadata={({ props }) => ({ width: 1080, height: LAYOUT[props.format].height, durationInFrames: STILL_FRAMES })} />
    <Composition id="Avatar" component={Avatar} width={1080} height={1080} fps={FPS} durationInFrames={STILL_FRAMES} />
  </>
);
