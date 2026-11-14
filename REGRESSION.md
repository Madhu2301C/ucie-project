# QuestaSim 10.4e regression

Use run_regression.ps1 as the regression entry point. The existing .do/.sh
scripts are preserved unchanged and retain their original finish/result
handling; this document does not certify those entry points.

## Commands (PowerShell)

    Set-Location -LiteralPath 'E:\ucie\RTL'
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_regression.ps1 -SelfTest
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_regression.ps1 -Tests tb_backpressure_test
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_regression.ps1

Omitting -Tests runs all 12 tests sequentially. Within PowerShell, a subset
can be passed as an array:

    & .\run_regression.ps1 -Tests @('tb_crc_compare','tb_crc_validation')

Options:
- QuestaBin: defaults to C:\questasim_10.4e\win32.
- SimLimitNs: defaults to 20000 ns per simulation.
- WallTimeoutSeconds: defaults to 60 seconds per child tool process, including
  library setup, compilation, design loading/optimization, and simulation.
- BuildRoot: defaults to regression_build under the project. Each invocation
  creates a unique directory; src, tb, work and backup directories are rejected.
- VectorFile: optional input override for tb_crc_randomized_independent.
  Relative input paths are resolved from the invoking shell's directory.

Each test gets its own copied configuration, mapped rxreg library, compiler
logs, simulator process, transcript, waveform file, and generated run.do.
The private configuration copy is made writable; installation/project
configuration and the original work library are not rebuilt or mapped over.
The simulator working directory remains the project root so existing vector
file reads continue to work.

## Completion and failures

The simulator explicitly uses -onfinish stop and onfinish stop.
onbreak resumes macro processing after a break, not testbench execution.
BreakOnAssertion is explicitly 2. The generated macro runs a bounded interval,
then emits REGRESSION_RUN_RETURNED and exits only that disposable process.
Individual SV testbenches contain no simulator application-exit commands.

PASS requires all of:
- successful setup/compilation and zero simulator process exit status;
- no host timeout;
- no actual Error/Fatal/Failure diagnostic or nonzero error summary;
- exactly one standalone REGRESSION_PASS: <top> marker;
- an actual $finish diagnostic and the runner-return marker.

Errors: 0 is not treated as an error. Completion messages emitted before
later failures cannot override those failures. Missing completion, duplicate
markers, missing finish, unexpected exit and timeout are failures.

The parent enforces a wall-clock deadline and kills only its own timed-out
child process tree. This covers zero-time loops and a blocked loader as well
as ordinary simulations. Simulation-time watchdogs cannot catch zero-time
loops; strict vector parsing is therefore also necessary.

summary.json and summary.csv record the outcome, reason, exit code, timeout
flag, elapsed simulator/tool seconds, and per-test log directory. Process
startup/infrastructure exceptions cause the PowerShell command to fail.
A nonzero final exit status indicates regression or self-test failure.

Protected SHA-256 hashes are recorded before each invocation and checked
afterward for src, the original work files, modelsim.ini, and existing
regression scripts. Do not run a separate simulator against the original work
library concurrently if you expect that library's hashes to remain stable.

## Controlled runner validation

-SelfTest compiles generated fixtures without project RTL. It verifies:
passing finish, fatal failure, error failure, failure after a completion
marker, missing completion, duplicate completion, simulation-time limit,
host timeout caused by a zero-time loop, and compiler error.

Expected failing fixtures must be classified with their expected reasons;
the self-test command succeeds only when every expected outcome matches.
Fatal/error probes must also contain their specific injected diagnostic.
These are infrastructure checks, not UCIe functional coverage.

## Testbench changes and originals

Byte-for-byte originals are retained in:
regression_backups/before_testbench_hardening/

All 12 testbenches now have a final completion marker and explicit 1ns/1ps
timescale. Existing explicit timescales were retained. Missing watchdogs were
added; backpressure/link deadlines are independent of clock edges.
Backpressure uses 1000 ns, link uses 2000 ns, other tests use 10000 ns.

The independent random-vector reader accepts exactly 1000 lines, each with
256 hexadecimal message digits and 4 CRC digits. It rejects malformed,
unknown, short, oversized, extra-token, extra-record, truncated and mismatching
input. Blank records are malformed. At most 1001 line reads are attempted.

CRC model comparison failures are fatal. The diagnostic CRC test now checks
local expected values. The extended CRC completion message follows all seven
cases. Randomized model-comparison and TX/RX tests use explicit seed 68b01234.

## Scope of validation

No src files or original regression scripts/configuration are modified.
The flit format, RTL CRC behavior, module interfaces and research abstract
are outside this change.

Passing local polynomial-division vectors, model-consistency tests and RX
corruption tests does not establish official UCIe CRC conformance. Official
golden vectors or an authoritative reference are still required.
