"""Acceptance: existing type bins must all be hit, never count instance duplicates."""
from pathlib import Path
import re,sys,json

def bins(path):
    text=Path(path).read_text(); group=None; active=False; result={}
    for line in text.splitlines():
        if line.startswith(' TYPE '):
            group=line.split()[1]; active=True; result[group]=[]
        elif line.startswith(' CLASS '): active=False
        if active and re.match(r'\s+bin ',line):
            parts=line.split()
            result[group].append({'name':parts[1],'rhs':parts[2],'hits':int(parts[3])})
    return result
if __name__=='__main__':
    result=bins(sys.argv[1]); total=sum(len(v) for v in result.values()); hit=sum(b['hits']>0 for v in result.values() for b in v)
    print(json.dumps({'hit':hit,'total':total,'groups':result},indent=2))
    assert total==45, f'Unexpected denominator {total}'
    assert hit==total, f'Missing functional bins: {total-hit}'
