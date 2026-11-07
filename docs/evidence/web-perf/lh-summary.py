# usage: python3 lh-summary.py <lighthouse.sh outdir>; medians of the three runs.
# Exits nonzero unless every page/mode has all three reports with no Lighthouse runtime error.
import json,os,statistics,sys
missing=[f for f in (f"{n}-{m}-{r}.json" for n in ('home','guide') for m in ('mobile','desktop') for r in (1,2,3)) if not os.path.isfile(os.path.join(sys.argv[1],f))]
if missing: sys.exit(f"missing reports: {', '.join(missing)}")
g={}
for name in ('guide','home'):
  for mode in ('desktop','mobile'):
    for run in (1,2,3):
      d=json.load(open(os.path.join(sys.argv[1],f"{name}-{mode}-{run}.json"))); a=d['audits']
      if d.get('runtimeError') or d['categories']['performance']['score'] is None: sys.exit(f"{name}-{mode}-{run}: Lighthouse runtime error {d.get('runtimeError')}")
      items=a['network-requests']['details']['items']
      doc=next(i for i in items if i.get('resourceType')=='Document')
      g.setdefault((name,mode),[]).append(dict(score=round(d['categories']['performance']['score']*100), fcp=a['first-contentful-paint']['numericValue'], lcp=a['largest-contentful-paint']['numericValue'], cls=a['cumulative-layout-shift']['numericValue'], tbt=a['total-blocking-time']['numericValue'], ttfb=a['server-response-time']['numericValue'], si=a['speed-index']['numericValue'], bytes=a['total-byte-weight']['numericValue'], reqs=len(items), docbytes=doc.get('transferSize'), rb=len(a.get('render-blocking-insight',a.get('render-blocking-resources',{})).get('details',{}).get('items',[]) or [])))
print("page | mode | score | FCP ms | LCP ms | CLS | TBT ms | TTFB ms (doc) | SI ms | transfer KB | requests | html KB")
for (n,m),v in g.items():
    med=lambda k: statistics.median(x[k] for x in v)
    print(f"{n} | {m} | {med('score'):.0f} | {med('fcp'):.0f} | {med('lcp'):.0f} | {med('cls'):.3f} | {med('tbt'):.0f} | {med('ttfb'):.0f} | {med('si'):.0f} | {med('bytes')/1024:.1f} | {med('reqs'):.0f} | {med('docbytes')/1024:.1f}  (runs LCP: {[round(x['lcp']) for x in v]})")
