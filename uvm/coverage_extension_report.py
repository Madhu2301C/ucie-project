from coverage_extension_run import ROOT, RTL, command, Q
from coverage_extension_verify import bins
from pathlib import Path
import json, os, re, hashlib, sys, subprocess
out=Path((ROOT/'logs'/'coverage_extension_latest.txt').read_text())
metrics={}
for label in ['before','after']:
    text=(out/(label+'_code.txt')).read_text()
    data={}
    for m in re.finditer(r'^\s+(Stmts|Branches|FEC Condition Terms|FEC Expression Terms|States|Transitions|Toggle Bins)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\d.]+)',text,re.M):
        row=data.setdefault(m[1],{'active':0,'hits':0,'misses':0})
        for key,i in [('active',2),('hits',3),('misses',4)]:row[key]+=int(m[i])
    per_file={}; current=None
    for line in text.splitlines():
        mf=re.match(r'===\s*File:\s*(.+)\s*$', line)
        if mf:
            current=mf.group(1).strip(); per_file[current]={}
        elif current:
            mm=re.match(r'\s+(Stmts|Branches|FEC Condition Terms|FEC Expression Terms|States|Transitions|Toggle Bins)\s+(\d+)\s+(\d+)\s+(\d+)\s+([\d.]+)', line)
            if mm:
                per_file[current][mm.group(1)]={'active':int(mm.group(2)),'hits':int(mm.group(3)),'misses':int(mm.group(4)),'percent':float(mm.group(5))}
    CATEGORIES=('Stmts','Branches','FEC Condition Terms','FEC Expression Terms','States','Transitions','Toggle Bins')
    data['per_file']=per_file
    for key in CATEGORIES:
        if key in data:
            row=data[key]; row['percent']=round(100*row['hits']/row['active'],3) if row['active'] else 100
    data['reported_total']=re.search(r'Total Coverage By File.*: ([\d.]+)%',text)[1]
    metrics[label]=data
CATEGORIES=('Stmts','Branches','FEC Condition Terms','FEC Expression Terms','States','Transitions','Toggle Bins')
for key in CATEGORIES:
    assert metrics['before'][key]['active']==metrics['after'][key]['active'], key
for file_path,row in metrics['before_per_file'].items() if False else metrics['before']['per_file'].items():
    assert file_path in metrics['after']['per_file'], file_path
    for metric,counts in row.items():
        assert counts['active']==metrics['after']['per_file'][file_path][metric]['active'], (file_path,metric)
functional={label:bins(out/(label+'_functional.txt')) for label in ['before','after']}
for label,groups in functional.items():
    print(label, 'bins',sum(b['hits']>0 for v in groups.values() for b in v),sum(len(v) for v in groups.values()))
    for group,bs in groups.items():
        print(group,[(b['name'],b['hits']) for b in bs if 'replay' in b['name']])
print(json.dumps(metrics,indent=2))
base=json.loads((out/'baseline_results.json').read_text()); ext=json.loads((out/'extension_results.json').read_text())
print('SCENARIOS',len(base),len(ext))
base_dir_env=os.environ.get('UCIE_COVERAGE_BASELINE_DIR')
base_path=Path(base_dir_env) if base_dir_env else out
original=base_path/'before_hashes.json'
staged_before=base_path/'staged_before.patch'
backup=base_path/'backup'
hashes=json.loads(original.read_text()); changed=[p for p,h in hashes.items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
assert not changed
assert (out/'staged_after.patch').read_bytes()==staged_before.read_bytes()
summary={'metrics':metrics,'functional':functional,'baseline_count':len(base),'extension_count':len(ext),'original_source_count':len(hashes),'changed_originals':changed,'staged_checkpoint_unchanged':True,'original_backup':str(backup),'baseline_dir':str(base_path)}
(out/'verified_summary.json').write_text(json.dumps(summary,indent=2))
p=subprocess.run([sys.executable,str(ROOT/'coverage_extension_verify.py'),str(out/'before_functional.txt')],capture_output=True,text=True)
(out/'functional_red.log').write_text(p.stdout+p.stderr); assert p.returncode!=0 and 'Missing functional bins: 3' in p.stderr
checks=[]
for result in base+ext:
    text=(out/(result['name']+'.log')).read_text()
    checks += [result['name']+': '+line for line in text.splitlines() if any(x in line for x in ['PASSED:','[EXT_COUNTS]','[EXT_CHECK_PASS]','Initial TX Count','Replay TX Count','ACK Count','NAK Count','Timeout Count','PASS:']) and not re.search(r'# \[',line)]
(out/'scenario_checks.txt').write_text('\n'.join(checks)+'\n')
print('FINAL_VERIFICATION_PASS '+str(out))
