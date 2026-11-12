/** One look for the whole trailer: near-black type on full colour fields, centred, one headline size. */
export const STYLE = {
  text: "#0A0A0C",
  headSize: 150,
  supportSize: 48,
  wordStep: 0.06, // seconds between headline words
  // Transitions, in frames at 30 fps, each centred on its cut: 0.5 s colour disc, 0.3 s screen cross-fade. Text leaves over the 0.25 s before a cut.
  colorFrames: 15,
  screenFrames: 9,
  exitSeconds: 0.25,
  exitDrift: 24,
  // The colour disc grows from the centre of the phone (deviceTop + half the bezel's 1020 px height).
  discOrigin: { x: 540, y: 1400 },
  // Text column inside the shared safe area x 120-960, y 380-1440.
  column: { left: 120, width: 840 },
  headTop: 380,
  headHeight: 300, // two lines; one-line headlines sit on the bottom edge
  supportTop: 700,
  counterTop: 780,
  // The bezel is the same size and place in every app shot and never moves.
  deviceScale: 0.34,
  deviceTop: 890,
} as const;
