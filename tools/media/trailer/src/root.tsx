import React from "react";
import { Composition } from "remotion";
import { Trailer } from "./trailer";

export const Root: React.FC = () => (
  <Composition
    id="Trailer"
    component={Trailer}
    width={1080}
    height={1920}
    fps={30}
    durationInFrames={900}
    defaultProps={{ variant: "coming-soon" as const, safeZones: false }}
  />
);
