# Coverage extension — verified QuestaSim 10.4e regression

## Result and reproducibility

Final evidence directory: `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419`.

Run from `E:/ucie/RTL/UVM`:

```
python coverage_extension_run.py
python coverage_extension_finish.py
python coverage_extension_report.py
```

The first command creates a fresh timestamped build, backs up and hashes sources, compiles UVM 1.1c and the existing RTL, then runs the original eight scenarios. The second compiles a separate test package and generated copy of tb_top whose only change is importing the additional package. It runs 21 additional positive scenarios and two intentional negative checker validations, merges only passing tests, and generates text and HTML reports. The third checks denominator equality, all functional bins, original source integrity and staged checkpoint preservation. It writes `verified_summary.json` and `scenario_checks.txt`. The original eight scenarios and production scoreboard are not overridden. New scenarios use independent explicit checks and existing unmodified monitors/coverage.

All 29 positive scenarios reached TEST_DONE with zero UVM warnings/errors/fatals and exact existing scoreboard pass markers or EXT_CHECK_PASS. Negative retry/link payload-expectation perturbations produced the intended EXT_CHECK fatal; neither UCDB is merged. Simulations are bounded at 100 us, with smaller operation deadlines in the new test.

## Coverage

Existing functional bins: **42/45 -> 45/45 (100%)**. No bin, goal, ignore or exclusion was changed.

Exact existing replay-depth ranges in `env/ucie_coverage.sv`: no_replay=0, single_replay=1, multiple_replays=[2:10], deep_replay=[11:$]. New formerly missing bin hits:

- retry_summary_cg.deep_replay: 1 (11 accepted replays).
- link_summary_cg.multiple_replays: 1 (2 accepted replays).
- link_summary_cg.deep_replay: 2 (11 and 64 accepted replays).

Same-instrumentation final baseline and extended comparison (code by file, including interfaces):

| Metric | Baseline | Extended | Active denominator |
|---|---:|---:|---:|
| Questa total code by file | 79.4% | 94.6% | Identical enabled categories/files |
| Statements | 97 | 97 | 99 |
| Branches | 37 | 38 | 40 |
| FEC condition terms | 9 | 15 | 17 |
| FEC expression terms | 2 | 2 | 2 |
| FSM states | 4 | 4 | 4 |
| FSM transitions | 6 | 8 | 8 |
| Toggle bins | 11,377 | 21,590 | 24,922 |

Both sides use `-cover bcesft`, `-togglewidthlimit 1024` at compile/simulation and `-voptargs=+acc`. Width 1024 includes payload/flit buses and the complete padded CRC message. This is intentionally broader than the historical default-width report, so the old recorded 80.6% must not be used as the comparable baseline. No old UCDBs were reused. Intermediate investigative directories are retained but are not the final result.

## Scenario additions

- RETRY_DEEP: 12 handshakes, 11 NAKs/replays, four initial stall cycles, replay stalls and retained-data checks after changing live request data.
- LINK_MULTIPLE / LINK_DEEP / LINK_LONG: respectively 3/12/65 handshakes and 2/11/64 actual CRC errors/replays. Exact payload, decoded header sequence, replay counter delta, completion and return-to-idle checks.
- BOUNDARY_9_ACK/NAK and BOUNDARY_10_ACK/NAK: four cases at timeout_count=9 or 10. Read back the actual counter and prove ACK/NAK suppress timeout at the boundary.
- RESET_0/1/2: pending asynchronous reset in SEND_NEW, WAIT_ACK and stalled SEND_REPLAY, followed by a quiet window proving no ghost replay.
- PAYLOAD_1..10: all-one, all-zero and eight independently seeded random payloads with varied sequence numbers.
- All extended link cases also exercise initial TX backpressure, send_req held while busy (ignored), and reset of completed registered results.

Repeated link corruption is deliberate **testbench-only** fault injection: `uvm_hdl_force` rearms `tb_top.link_dut.injected_once`, then stops corruption at the requested depth and releases the force after completion. It does not modify RTL or force CRC outputs, ACK/NAK, counters, data or completion. The checker observes real receiver CRC decisions on accepted handshakes. It does not interpret the sticky crc_error_seen flag as a per-error counter.

## Remaining gaps (not excluded)

- Two retry-controller statements and one branch are default recovery from an invalid state. All four two-bit state encodings are legal; normal binary stimulus cannot reach that default. No X/state forcing was used to inflate this result.
- Two retry handshake FEC terms require tx_valid=0 while executing SEND_NEW/SEND_REPLAY, where combinational RTL guarantees tx_valid=1.
- The remaining link branch is the no-CRC-error and not-valid receiver outcome; flit_valid is the complement of crc_error for known inputs. No unknown-input forcing was used.
- Remaining toggles include fixed regular-header fields, tied-off stack/ACK-type fields, zero padding in the 1024-bit CRC message, the CRC loop integer (not observed toggling by this instrumentation), and replay-counter bits [31:7]. The counter was exercised through 64, not forced toward overflow. These high counter bits are untested, not logically unreachable.
- Parameter variants of TIMEOUT_CYCLES, arbitrary X behavior, long counter overflow and general protocol conformance are outside this regression. 100% functional coverage means the existing 45 bins, not exhaustive correctness.

## Preservation and files

No pre-existing SV file, RTL, scoreboard, scenario, coverage definition, original compile script, package or tb_top was edited. The initial pre-edit backup and SHA-256 list are at `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_084231/backup` and `before_hashes.json`. Final verification compares all 33 original SV files against that initial list; all match. The staged binary diff also matches the original checkpoint byte-for-byte. No commits, resets, stashes, staging or unstaging were performed.

Added source/tool files under `E:/ucie/RTL/UVM`:

- `tests/ucie_coverage_container.sv`
- `tests/ucie_coverage_extension_test.sv`
- `ucie_coverage_extension_pkg.sv`
- `coverage_extension_run.py`
- `coverage_extension_finish.py`
- `coverage_extension_verify.py`
- `coverage_extension_report.py`
- `COVERAGE_EXTENSION.md`

Generated build/backup/log/report/UCDB/HTML files are under timestamped `logs/coverage_extension_*` directories; `logs/coverage_extension_latest.txt` points to the final run. Runtime Python may also create `__pycache__`.

Key final artifacts:

- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/before.ucdb`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/after.ucdb`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/before_code.txt`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/after_code.txt`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/after_code_details.txt`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/after_functional.txt`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/verified_summary.json`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/scenario_checks.txt`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/functional_red.log` and `functional_green.log`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/NEG_RETRY.log` and `NEG_LINK.log`
- `E:/ucie/RTL/UVM/logs/coverage_extension_20261114_090419/html/index.html`

Questa 10.4e issues resolved during test development: inherited UVM `check` method name collision, abstract uvm_component allocation, received sequence encoded across two header nibbles, and undefined upper bits in uvm_hdl_data_t reads. Final runs above are clean.
