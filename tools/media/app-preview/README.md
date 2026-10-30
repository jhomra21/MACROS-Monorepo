# App preview renderer

Browser tool that turns simulator screen recordings into App Store app previews: 886x1920, 30 fps, H.264 (High 4.0) in MP4 with a silent stereo AAC track. It runs on Mediabunny (WebCodecs), so nothing is installed.

Serve the folder and open it in a Chromium-based browser (the T3 preview browser works):

```sh
# Mac
python3 -m http.server 8765 --directory tools/media/app-preview
# Windows
py -3 -m http.server 8765 --directory tools\media\app-preview
```

Then open http://127.0.0.1:8765/, choose the clips in order, edit the JSON config (per-clip `start`/`end` in seconds, optional `label` pill, optional `endCard`), and press Render. The MP4 downloads when the render finishes; `window.__previewResult` reports `{status, name, bytes, durationSec, frames}` for scripted runs. "Self-test" renders a synthetic clip end to end without any input file.

Record clips on the simulator with `xcrun simctl io <udid> recordVideo --codec h264 --force <file>.mov` and stop the recording with SIGINT. Keep each finished preview between 15 and 30 seconds.
