# usage: python3 analyze.py <measure.sh output>...; per host+path p50/p95 of TTFB and server time (TTFB minus TLS done).
import sys, collections, statistics
def pct(xs,p):
    xs=sorted(xs); k=(len(xs)-1)*p; f=int(k); c=min(f+1,len(xs)-1); return xs[f]+(xs[c]-xs[f])*(k-f)
for fn in sys.argv[1:]:
    rows=collections.OrderedDict()
    for line in open(fn):
        t=line.split()
        host,path,i=t[0],t[1],int(t[2]); dns,con,tls,ttfb,tot=map(float,t[3:8]); size=int(t[8]); hv=t[9]; code=t[10]
        kv=dict(x.split('=',1) for x in t[11:])
        rows.setdefault(host+path,[]).append(dict(i=i,dns=dns,con=con,tls=tls,ttfb=ttfb,tot=tot,srv=ttfb-tls,size=size,hv=hv,code=code,**kv))
    print(f"## {fn.split('/')[-1]}")
    print("path | code | n | first ttfb ms | ttfb p50/p95 ms | server(ttfb-tls) p50/p95 ms | tcp p50 | tls-tcp p50 | size | http | cache | enc | etag | colos")
    for p,rs in rows.items():
        ms=lambda k,q: round(pct([r[k] for r in rs],q)*1000)
        srv=[r['srv'] for r in rs]
        colos=collections.Counter(r['ray'].split('-')[-1] for r in rs)
        cache=collections.Counter(r['cache'] for r in rs)
        print(f"{p} | {rs[0]['code']} | {len(rs)} | {round(rs[0]['ttfb']*1000)} | {ms('ttfb',.5)}/{ms('ttfb',.95)} | {round(pct(srv,.5)*1000)}/{round(pct(srv,.95)*1000)} | {round(pct([r['con']-r['dns'] for r in rs],.5)*1000)} | {round(pct([r['tls']-r['con'] for r in rs],.5)*1000)} | {rs[0]['size']} | {rs[0]['hv']} | {dict(cache)} | {rs[0]['enc']} | {rs[0]['etag']} | {dict(colos)}")
