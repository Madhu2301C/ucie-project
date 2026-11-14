from coverage_extension_run import *
from coverage_extension_verify import bins
import os
out=Path((ROOT/'logs'/'coverage_extension_latest.txt').read_text())
build=out/'build'
top=(ROOT/'tb_top.sv').read_text().replace('import ucie_pkg::*;','import ucie_pkg::*;\n    import ucie_coverage_extension_pkg::*;')
(build/'tb_top_extension.sv').write_text(top)
tcl=f'''onerror {{quit -code 1}}
vlog -work work -sv -L uvm_lib +incdir+C:/questasim_10.4e/verilog_src/uvm-1.1c/src +incdir+{ROOT.as_posix()}/tests {ROOT.as_posix()}/ucie_coverage_extension_pkg.sv
vlog -work work -sv -L uvm_lib {build.as_posix()}/tb_top_extension.sv
quit -code 0
'''
(build/'extension.tcl').write_text(tcl)
command([Q/'vsim.exe','-c','-do','do '+(build/'extension.tcl').as_posix()],build,out/'extension_compile.log')
scenarios=[('RETRY_DEEP',['+EXT_CASE=RETRY_DEEP']),('LINK_MULTIPLE',['+EXT_CASE=LINK','+DEPTH=2']),('LINK_DEEP',['+EXT_CASE=LINK','+DEPTH=11'])]
if '--smoke' in sys.argv: scenarios=scenarios[:1]
else:
    scenarios += [('LINK_LONG',['+EXT_CASE=LINK','+DEPTH=64','+PATTERN=3'])]
    scenarios += [(f'BOUNDARY_{delay}_{kind}',['+EXT_CASE=BOUNDARY',f'+BOUNDARY={delay}']+(['+BOUNDARY_NAK'] if kind=='NAK' else [])) for delay in [9,10] for kind in ['ACK','NAK']]
    scenarios += [(f'RESET_{state}',['+EXT_CASE=RESET',f'+RESET_STATE={state}']) for state in range(3)]
    scenarios += [(f'PAYLOAD_{p}',['+EXT_CASE=LINK','+DEPTH=0',f'+PATTERN={p}']) for p in range(1,11)]
results=[]
for name,args in scenarios:
    results.append(run(out,name,test='ucie_coverage_extension_test',extra=args))
    if not results[-1]['clean'] or not results[-1]['done']: raise RuntimeError('Scenario failed '+name)
(out/'extension_results.json').write_text(json.dumps(results,indent=2))
if '--smoke' not in sys.argv:
    # Negative checker validation is deliberately excluded from all coverage merges.
    NEGATIVE_EXPECTED={
        'NEG_RETRY':'accepted retry payload mismatch',
        'NEG_LINK':'link recovered payload mismatch',
    }
    for name,args in [('NEG_RETRY',['+EXT_CASE=RETRY_DEEP']),('NEG_LINK',['+EXT_CASE=LINK','+DEPTH=2'])]:
        result=run(out,name,test='ucie_coverage_extension_test',extra=args+['+EXT_NEGATIVE'])
        text=(out/(name+'.log')).read_text()
        assert not result['clean'] and not result['done'], name
        assert f'[EXT_CHECK] {NEGATIVE_EXPECTED[name]}' in text, (name, text[-800:])
        counts=re.search(r'# UVM_INFO\s*:\s*(\d+)\s*\r?\n# UVM_WARNING\s*:\s*(\d+)\s*\r?\n# UVM_ERROR\s*:\s*(\d+)\s*\r?\n# UVM_FATAL\s*:\s*(\d+)', text)
        assert counts, (name, text[-800:])
        assert (int(counts.group(2)),int(counts.group(3)),int(counts.group(4)))==(0,0,1), (name,counts.groups())
    baseline=json.loads((out/'baseline_results.json').read_text())
    reports(out,'after',[r['name'] for r in baseline+results])
    verify_args=[out/'after_functional.txt']
    base_dir=os.environ.get('UCIE_COVERAGE_BASELINE_DIR')
    if base_dir:
        verify_args += ['--baseline-dir',base_dir]
    command([sys.executable,ROOT/'coverage_extension_verify.py',*verify_args],build,out/'functional_green.log')
    before=json.loads((out/'before_hashes.json').read_text())
    differences=[p for p,h in before.items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
    (out/'source_integrity.json').write_text(json.dumps({'original_files_checked':len(before),'changed':differences},indent=2))
    assert not differences
    command(['git','diff','--cached','--binary'],RTL,out/'staged_after.patch')
    assert (out/'staged_before.patch').read_bytes()==(out/'staged_after.patch').read_bytes()
    command([Q/'vcover.exe','report','-html','-htmldir',out/'html','-codeAll' if False else '-code','bcesft','-cvg',out/'after.ucdb'],build,out/'html_command.log')
    print('EXTENSION_PASS '+str(out))
