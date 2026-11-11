/** One look for the whole trailer: near-black type on full colour fields, centred, one headline size. */
export const STYLE = {
  text: "#0A0A0C",
  headSize: 150,
  supportSize: 48,
  wordStep: 0.2, // seconds between headline words
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
