import React from "react";
import { Composition } from "remotion";
import { Trailer, type Props } from "./trailer";

const defaultProps: Props = { variant: "coming-soon", safeZones: false };

export const Root: React.FC = () => (
  <Composition id="Trailer" component={Trailer} width={1080} height={1920} fps={30} durationInFrames={900} defaultProps={defaultProps} />
);
