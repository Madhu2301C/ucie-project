# UCIe regression progress checkpoint

Project: E:\ucie\RTL
Checkpoint date: 2026-10-18

## Current status

- Regression infrastructure implemented and validated with QuestaSim 10.4e.
- All 12 hardened testbenches passed individually.
- Full sequential regression: 12/12 PASS.
- Controlled runner checks: 9/9 expected outcomes.
- Negative vector-input checks: 8/8 correctly rejected.
- RX mapping test exercised all 544 single-bit corruptions, X/Z rejection,
  and recovery: 2198 status checks.
- Backpressure passed at 140 ns: accepts=1 deliveries=1 stalled_checks=5.
- Official UCIe CRC conformance remains UNVALIDATED. Authoritative golden
  vectors or an authoritative reference implementation are still required.

## Files and entry point

New runner: run_regression.ps1
Documentation: REGRESSION.md
Changed verification sources: all 12 tb\*.sv files.
Byte-for-byte original testbenches:
regression_backups\before_testbench_hardening\

The runner uses separate batch simulator processes and private per-test
libraries/configuration under a unique regression_build directory. It sets
-onfinish stop, enforces simulation-time and host wall-clock limits, and
requires a unique final completion marker, $finish evidence, runner return,
zero exit status, and no HDL/tool errors before declaring PASS.
Default limits: 20000 ns simulated time and 60 seconds per child tool process.

Testbench changes include bounded strict vector-file parsing, fatal CRC
comparison failures, actual checks in the former diagnostic CRC test,
correctly positioned final messages, completion markers, missing watchdogs,
explicit timescales where absent, and explicit randomized-test seeds.
Backpressure/link watchdogs are independent of clock edges.

## Saved evidence

Full regression:
regression_build\20261018_192410_358_769b42bf\summary.json
regression_build\20261018_192410_358_769b42bf\summary.csv
Per-test compile.log, process.log, transcript.log, run.do, modelsim.ini,
library and waveform artifacts are in that directory's test subdirectories.

Final runner controlled validation:
regression_build\20261018_192308_113_9add7486\summary.json

Negative vector-input validation:
regression_build\vector_input_checks\summary.json
Cases: malformed, unknown, short, extra_token, empty, truncated, extra_record,
and mismatch. Expected fatal failures were observed for all eight.

## Full regression outcomes

Every row: Status=PASS, Reason=COMPLETED, ExitCode=0, TimedOut=false.
Every log: exactly one matching REGRESSION_PASS: <test> marker, one $finish,
and one REGRESSION_RUN_RETURNED marker; no compiler/simulator errors.

Test                              Finish time
tb_backpressure_test               140 ns
tb_crc_compare                     3 ns
tb_crc_independent_vectors         7 ns
tb_crc_randomized                  1 us
tb_crc_randomized_independent      1 us
tb_crc_validation                 20 ns
tb_ucie68b_flit_rx_mapping          2219 ns
tb_ucie68b_flit_tx_mapping          6 ns
tb_ucie68b_header_encoder          3 ns
tb_ucie68b_tx_rx_integration        768 ns
tb_ucie_crc16_candidate            7 ns
tb_ucie_link_top                   160 ns

## Read-only audit findings

The JSON and CSV agree on all 12 results and all fields.
Each test was freshly compiled, mapped to its own private library, optimized,
and simulated within the full-run directory. Sequential simulator timestamps:
2026-10-18 19:24:12 through 19:24:58. The runner does not import earlier results.

The misleading final read-only displays "Runner self-tests matched: 0/1" and
"Vector negative checks matched: 0/1" were counting-command errors, not test
failures. In this PowerShell environment, wrapping the ConvertFrom-Json
pipeline in @(...) produced a single nested array. Filtering then examined
that array rather than individual rows. Both displays were reproduced.
Direct assignment and foreach iteration confirmed 9/9 and 8/8.
Saved reports were not modified.

CRC implementation: zero initialization, message[0] first, 1024 processed
bits, left-shifting recurrence with polynomial 8005, no final XOR.
Candidate and SV reference share the same recurrence; their agreement alone
is model consistency, not independent CRC validation.

Read-only mathematical recomputation matched all local directed constants
and all 1000 existing file vectors against recurrence and polynomial division,
including deterministic file-vector seed 20261018.
Directed values:
zeros=0000, message bit 0=8039, message bit 8=0B00, all FF=002E,
AA/55=D4CC, 55/AA=D4E2, walking byte bits=EF52,
walking complements=EF7C, incrementing bytes=249F.
These are local convention checks, not official UCIe golden vectors.

Flit mapping remains 544 bits (68 bytes):
header byte 0 [7:0], header byte 1 [15:8], payload [527:16],
CRC low byte [535:528], CRC high byte [543:536].
CRC message [527:0] contains headers/payload; [1023:528] is zero padding.

Audit limitations: reports lack testbench/vector content hashes; marker and
error counts are evidenced by logs rather than separate summary fields.

## Preservation constraints

Do not modify src\ RTL, the 68-byte flit format, CRC behavior, interfaces, or
approved research abstract.
No src files were changed by this regression implementation.
Existing source modifications visible in Git predated this work.
The original work library, modelsim.ini, and original .do/.sh regression
scripts were preserved. Hash comparisons found zero changes to protected
files against the initial and full-run baselines.
Original runner scripts retain their old behavior; use run_regression.ps1.

The final audit was read-only: no simulations rerun or files modified.

## Commands for future use

From PowerShell:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\ucie\RTL\run_regression.ps1 -SelfTest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\ucie\RTL\run_regression.ps1 -Tests tb_backpressure_test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File E:\ucie\RTL\run_regression.ps1

The last command runs all 12 tests. Do not infer a later run passed without
checking its own reports and logs.

## Remaining work

No required regression implementation work remains from the approved scope.
Research milestone still requires authoritative UCIe CRC validation.
Any future strengthening of provenance (source/vector hashes) or explicit
summary marker/error-count fields is a separate change.
