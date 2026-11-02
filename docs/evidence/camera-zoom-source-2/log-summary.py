from pathlib import Path
import re

out=Path(__file__).parent
sections=[]
for prefix in ("original", "first-fix", "candidate"):
    for suffix in ("geometry.log", "dashboard-geometry.log"):
        path=out/f"{prefix}-{suffix}"
        if not path.exists():
            continue
        lines=path.read_text().splitlines()
        current=None
        for line in lines:
            match=re.match(r"ZOOM ([\d.]+) (.*)",line)
            if not match:
                continue
            stamp=float(match[1])
            event=match[2]
            if event.startswith("tap "):
                current=None
                if "camera" in event or "compact=" in event:
                    current={"case":f"{prefix}: {event}","tap":stamp,"events":[]}
                    sections.append(current)
            if current and stamp-current["tap"] <= .600:
                current["events"].append(f"+{(stamp-current['tap'])*1000:7.2f}ms {event}")
output=[]
for section in sections:
    output.append(f"\n## {section['case']} (tap epoch {section['tap']})")
    output.extend(section["events"])
(out/"first-600ms.log").write_text("\n".join(output)+"\n")
print("\n".join(output))
