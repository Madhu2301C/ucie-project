# UCIe RTL/UVM checkpoint

## Status
- Eight UVM scenarios were clean-built and run with QuestaSim 10.4e / UVM 1.1c: TC01, TC02, TC03, TC04, TC05, TC06, LINK_NORMAL, LINK_ERROR.
- Latest checkpoint verification logs: uvm/logs/checkpoint_verify/.
- All eight reached TEST_DONE with UVM_WARNING=0, UVM_ERROR=0, UVM_FATAL=0 in the recorded run.
- Latest coverage run: uvm/logs/updated_coverage_regression/.
- Recorded merged functional coverage: 97.3%; bins 42/45 (93.3%). Code coverage by file: 80.6%.
- Missing functional bins: retry deep replay; link multiple replay; link deep replay.
- These results describe the saved runs, not a new simulation performed while saving this note.

## Build and scenario selection
From E:/ucie/RTL/UVM:

```sh
vsim -c -do "do compile_smoke.tcl"
vsim -c -L uvm_lib -sv_lib C:/questasim_10.4e/uvm-1.1c/win32/uvm_dpi work.tb_top +UVM_TESTNAME=ucie_base_test +TEST_MODE=RETRY +UCIE_TESTCASE=TC01 +UVM_NO_RELNOTES -do "do E:/ucie/RTL/UVM/run_one.do"
```

Use RETRY with TC01 through TC06; use LINK with LINK_NORMAL or LINK_ERROR. Inspect UVM severity summaries and completion evidence; simulator exit code alone is insufficient.

## Preservation and review
- Source, testbench, UVM, reference, script and documentation changes are staged in Git.
- Generated libraries, logs, waves, UCDBs and backup directories are excluded by .gitignore; they remain on disk.
- Independent pre-commit review failed to execute due to provider HTTP 429 usage limits. Review is NOT approved.
- No verified commit has been created for this checkpoint. Preserve staged changes; do not reset or discard them.
- A separate checkpoint archive preserves the Git staged patch and source files, plus the latest verification logs and coverage reports.

## Next steps
1. Complete independent review before making a verified commit.
2. Review regression runner compatibility with the expanded link environment.
3. Extend coverage only with user approval; retain the individually passing scenarios.
