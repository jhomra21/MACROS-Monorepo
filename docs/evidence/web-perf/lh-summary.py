# usage: python3 lh-summary.py <lighthouse.sh outdir>; medians of the three runs.
import json,glob,os,statistics,sys,collections
g=collections.defaultdict(list)
for f in sorted(glob.glob(sys.argv[1]+'/*.json')):
    name,mode,run=os.path.basename(f)[:-5].split('-'); d=json.load(open(f)); a=d['audits']
    items=a['network-requests']['details']['items']
    doc=next(i for i in items if i.get('resourceType')=='Document')
    g[(name,mode)].append(dict(score=round(d['categories']['performance']['score']*100), fcp=a['first-contentful-paint']['numericValue'], lcp=a['largest-contentful-paint']['numericValue'], cls=a['cumulative-layout-shift']['numericValue'], tbt=a['total-blocking-time']['numericValue'], ttfb=a['server-response-time']['numericValue'], si=a['speed-index']['numericValue'], bytes=a['total-byte-weight']['numericValue'], reqs=len(items), docbytes=doc.get('transferSize'), rb=len(a.get('render-blocking-insight',a.get('render-blocking-resources',{})).get('details',{}).get('items',[]) or [])))
print("page | mode | score | FCP ms | LCP ms | CLS | TBT ms | TTFB ms (doc) | SI ms | transfer KB | requests | html KB")
for (n,m),v in sorted(g.items()):
    med=lambda k: statistics.median(x[k] for x in v)
    print(f"{n} | {m} | {med('score'):.0f} | {med('fcp'):.0f} | {med('lcp'):.0f} | {med('cls'):.3f} | {med('tbt'):.0f} | {med('ttfb'):.0f} | {med('si'):.0f} | {med('bytes')/1024:.1f} | {med('reqs'):.0f} | {med('docbytes')/1024:.1f}  (runs LCP: {[round(x['lcp']) for x in v]})")
