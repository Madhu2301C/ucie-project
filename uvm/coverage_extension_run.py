"""Fresh isolated Questa coverage regression; never modifies existing sources/index."""
from pathlib import Path
import subprocess, json, hashlib, shutil, datetime, re, sys
ROOT=Path('E:/ucie/RTL/UVM'); RTL=ROOT.parent
Q=Path('C:/questasim_10.4e/win32')
def command(args,cwd,log):
    p=subprocess.run([str(x) for x in args],cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=240)
    Path(log).write_text(p.stdout)
    if p.returncode: raise RuntimeError(f'{args}: {p.returncode}; see {log}')
    return p.stdout

def prepare():
    out=ROOT/'logs'/('coverage_extension_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'))
    out.mkdir(parents=True); (out/'build').mkdir(); (out/'backup').mkdir()
    files=list((RTL/'src').glob('*.sv'))+[p for p in ROOT.rglob('*.sv') if not any(x in p.parts for x in ['logs','work','uvm_lib'])]
    hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    for p in files:
        dest=out/'backup'/p.relative_to(RTL); dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,dest)
    (out/'before_hashes.json').write_text(json.dumps(hashes,indent=2))
    command(['git','status','--short'],RTL,out/'git_before.txt')
    command(['git','diff','--cached','--binary'],RTL,out/'staged_before.patch')
    script=(ROOT/'compile_smoke.tcl').read_text().replace('vlog -work work -sv -L uvm_lib \\\n  $ROOT/interfaces','vlog -cover bcesft -togglewidthlimit 1024 -work work -sv -L uvm_lib \\\n  $ROOT/interfaces')
    script=script.replace('  +incdir+$UVM_SRC \\\n  +incdir+$ROOT/common','  +incdir+$UVM_SRC \\\n  +incdir+$ROOT \\\n  +incdir+$ROOT/common')
    (out/'build'/'compile.tcl').write_text(script)
    command([Q/'vsim.exe','-c','-do',f'do {out.as_posix()}/build/compile.tcl'],out/'build',out/'compile.log')
    (ROOT/'logs'/'coverage_extension_latest.txt').write_text(str(out))
    return out

def run(out,name,test='ucie_base_test',mode='RETRY',case='TC01',extra=()):
    do=out/(name+'.do'); ucdb=out/(name+'.ucdb')
    do.write_text(f'onbreak {{resume}}\ncoverage save -onexit {ucdb.as_posix()}\nrun 100 us\ncoverage save {ucdb.as_posix()}\nquit -f\n')
    text=command([Q/'vsim.exe','-c','-coverage','-togglewidthlimit','1024','-sv_seed',str(int(hashlib.sha256(name.encode()).hexdigest()[:7],16)),'-voptargs=+acc','-L','uvm_lib','-sv_lib','C:/questasim_10.4e/uvm-1.1c/win32/uvm_dpi','work.tb_top','+UVM_TESTNAME='+test,'+TEST_MODE='+mode,'+UCIE_TESTCASE='+case,*extra,'-do','do '+do.as_posix()],out/'build',out/(name+'.log'))
    clean=all(re.search(r'UVM_'+s+r'\s*:\s*0\b',text) for s in ['WARNING','ERROR','FATAL'])
    done=('TEST_DONE' in text)
    if test=='ucie_base_test':
        required=([f'TEST {case} PASSED: All expected counts matched'] if mode=='RETRY' else
          (['PASS: Initial transmission observed','PASS: Payload matches expected value','PASS: Transaction completed successfully','PASS: No CRC errors in normal transmission','PASS: No replay in normal transmission','PASS: Sequence number matches'] if case=='LINK_NORMAL' else
           ['PASS: CRC error detected with error injection','PASS: Replay observed','PASS: Transaction completed after error','PASS: Payload recovered successfully after replay','PASS: Sequence number matches after replay']))
        done=done and all(x in text for x in required)
    else: done=done and 'EXT_CHECK_PASS' in text
    result={'name':name,'clean':clean,'done':done,'ucdb':str(ucdb)}
    print(json.dumps(result),flush=True)
    return result

def reports(out,label,names):
    db=out/(label+'.ucdb')
    command([Q/'vcover.exe','merge',db,*[out/(n+'.ucdb') for n in names]],out/'build',out/(label+'_merge.log'))
    for suffix,args in [('functional',['-cvg','-details','-binrhs']),('code',['-codeAll','-byfile']),('code_details',['-codeAll','-details','-byfile'])]:
        command([Q/'vcover.exe','report',*args,'-file',out/(label+'_'+suffix+'.txt'),db],out/'build',out/(label+'_'+suffix+'_command.log'))
    return db
if __name__=='__main__':
    out=prepare(); results=[]
    for n in ['TC01','TC02','TC03','TC04','TC05','TC06','LINK_NORMAL','LINK_ERROR']:
        results.append(run(out,n,mode='LINK' if n.startswith('LINK') else 'RETRY',case=n))
    (out/'baseline_results.json').write_text(json.dumps(results,indent=2))
    reports(out,'before',[r['name'] for r in results])
    assert all(r['clean'] and r['done'] for r in results), 'Baseline acceptance failed'
    print('BASELINE_PASS '+str(out))
