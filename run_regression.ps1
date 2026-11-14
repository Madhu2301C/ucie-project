#requires -Version 5.1
[CmdletBinding()]
param(
    [string[]]$Tests = @(),
    [switch]$SelfTest,
    [string]$VectorFile = '',
    [string]$QuestaBin = 'C:\questasim_10.4e\win32',
    [ValidateRange(1,3600)][int]$WallTimeoutSeconds = 60,
    [ValidateRange(1,100000000)][int]$SimLimitNs = 20000,
    [string]$BuildRoot = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $MyInvocation.MyCommand.Path
if (!$BuildRoot) { $BuildRoot = Join-Path $project 'regression_build' }
$BuildRoot = [System.IO.Path]::GetFullPath($BuildRoot)
foreach ($reserved in @('src','tb','work','regression_backups')) {
    $reservedPath = [System.IO.Path]::GetFullPath((Join-Path $project $reserved)).TrimEnd('\')
    if ($BuildRoot.TrimEnd('\') -eq $reservedPath -or
        $BuildRoot.StartsWith($reservedPath + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "BuildRoot must be separate from $reserved"
    }
}
$knownTests = @(
    'tb_backpressure_test', 'tb_crc_compare', 'tb_crc_independent_vectors',
    'tb_crc_randomized', 'tb_crc_randomized_independent', 'tb_crc_validation',
    'tb_ucie68b_flit_rx_mapping', 'tb_ucie68b_flit_tx_mapping',
    'tb_ucie68b_header_encoder', 'tb_ucie68b_tx_rx_integration',
    'tb_ucie_crc16_candidate', 'tb_ucie_link_top', 'tb_ucie_retry_controller'
)
$rtl = @(
    'ucie_crc16_candidate.sv', 'ucie_crc16_reference.sv',
    'ucie68_header_encoder.sv', 'ucie68b_flit_tx.sv', 'ucie68b_flit_rx.sv',
    'ucie_retry_controller.sv', 'ucie_link_top.sv'
)
foreach ($exe in @('vlib','vmap','vlog','vsim')) {
    if (!(Test-Path -LiteralPath (Join-Path $QuestaBin "$exe.exe"))) {
        throw "Missing Questa executable: $exe"
    }
}
if ($VectorFile) {
    $VectorFile = [System.IO.Path]::GetFullPath($VectorFile)
}
if (!$SelfTest) {
    if ($Tests.Count -eq 0) { $Tests = $knownTests }
    $Tests = @($Tests | Select-Object -Unique)
    foreach ($test in $Tests) {
        if ($test -notin $knownTests) { throw "Unknown test: $test" }
    }
}
$runDir = Join-Path $BuildRoot ((Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$protected = @(
    Get-ChildItem -LiteralPath (Join-Path $project 'src') -File -Recurse
    if (Test-Path -LiteralPath (Join-Path $project 'work')) {
        Get-ChildItem -LiteralPath (Join-Path $project 'work') -File -Recurse
    }
    foreach ($name in @('modelsim.ini','run_regression.do','run_all_tb.sh','_run_tb.sh','run_regression_safe.sh')) {
        $path = Join-Path $project $name
        if (Test-Path -LiteralPath $path) { Get-Item -LiteralPath $path }
    }
)
$before = @{}
foreach ($file in $protected) {
    $before[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
}
$before | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDir 'protected_hashes_before.json') -Encoding ASCII

function Invoke-Tool {
    param([string]$Exe, [string[]]$ToolArgs, [string]$Cwd, [string]$Log, [int]$Limit)
    $quoted = foreach ($arg in $ToolArgs) {
        if ($arg.Contains('"')) { throw "Unsupported quote in tool argument: $arg" }
        '"' + $arg.Replace('\','/') + '"'
    }
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = Join-Path $QuestaBin "$Exe.exe"
    $start.Arguments = $quoted -join ' '
    $start.WorkingDirectory = $Cwd
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        while (!$process.WaitForExit(200)) {
            if ($timer.Elapsed.TotalSeconds -ge $Limit) {
                $timedOut = $true
                & "$env:SystemRoot\System32\taskkill.exe" /PID $process.Id /T /F | Out-Null
                break
            }
        }
        if (!$process.WaitForExit(10000)) { throw "Child did not terminate: $Exe" }
        $outText = $stdout.GetAwaiter().GetResult()
        $errText = $stderr.GetAwaiter().GetResult()
        $text = $outText + [Environment]::NewLine + $errText
        [System.IO.File]::WriteAllText($Log, $text)
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            TimedOut = $timedOut
            Seconds = [Math]::Round($timer.Elapsed.TotalSeconds,3)
            Text = $text
        }
    }
    finally { $process.Dispose() }
}
function Has-ToolError([string]$Text) {
    return ($Text -match '(?im)^\s*(?:#\s*)?\*\*\s*(?:Error|Fatal|Failure)\b' -or
            $Text -match '(?im)^\s*(?:#\s*)?(?:Error|Fatal|Failure)\s*:' -or
            $Text -match '(?im)^\s*(?:#\s*)?Errors:\s*[1-9]\d*\b' -or
            $Text -match '(?im)^\s*(?:#\s*)?FAIL(?:ED)?(?:\s|:)')
}
function Run-One {
    param([string]$Top, [string[]]$Sources, [int]$SimNs, [int]$WallSeconds)
    $caseDir = Join-Path $runDir $Top
    New-Item -ItemType Directory -Path $caseDir | Out-Null
    $ini = Join-Path $caseDir 'modelsim.ini'
    Copy-Item -LiteralPath (Join-Path (Split-Path $QuestaBin -Parent) 'modelsim.ini') -Destination $ini
    (Get-Item -LiteralPath $ini).IsReadOnly = $false
    $library = Join-Path $caseDir 'library'
    $result = [ordered]@{
        Test = $Top; Status = 'FAIL'; Reason = ''; ExitCode = $null
        TimedOut = $false; Seconds = 0; Directory = $caseDir
    }
    $setup = @(
        @{ Exe='vlib'; Args=@($library); Log='vlib.log' },
        @{ Exe='vmap'; Args=@('-modelsimini',$ini,'rxreg',$library); Log='vmap.log' },
        @{ Exe='vlog'; Args=(@('-modelsimini',$ini,'-sv','-work','rxreg') + $Sources); Log='compile.log' }
    )
    foreach ($step in $setup) {
        $tool = Invoke-Tool $step.Exe $step.Args $caseDir (Join-Path $caseDir $step.Log) $WallSeconds
        if ($tool.TimedOut -or $tool.ExitCode -ne 0 -or (Has-ToolError $tool.Text)) {
            $result.Reason = if ($tool.TimedOut) { 'BUILD_TIMEOUT' } else { 'BUILD_ERROR' }
            $result.ExitCode = $tool.ExitCode
            $result.TimedOut = $tool.TimedOut
            $result.Seconds = $tool.Seconds
            return [pscustomobject]$result
        }
    }
    # Application exit commands execute only in this disposable child process.
    $do = Join-Path $caseDir 'run.do'
    @(
        'onerror {quit -code 2 -force}'
        'onbreak {resume}'
        'set BreakOnAssertion 2'
        'onfinish stop'
        "run $SimNs ns"
        'puts "REGRESSION_RUN_RETURNED"'
        'quit -code 0 -force'
    ) | Set-Content -LiteralPath $do -Encoding ASCII
    $doForward = $do.Replace('\','/')
    $simArgs = @(
        '-c','-modelsimini',$ini,'-onfinish','stop',
        '-wlf',(Join-Path $caseDir 'waves.wlf'),
        '-l',(Join-Path $caseDir 'transcript.log'),
        "rxreg.$Top",'-do',"do {$doForward}"
    )
    if ($Top -eq 'tb_crc_randomized_independent' -and $VectorFile) {
        $simArgs += "+VECTOR_FILE=$VectorFile"
    }
    $sim = Invoke-Tool 'vsim' $simArgs $project (Join-Path $caseDir 'process.log') $WallSeconds
    $result.ExitCode = $sim.ExitCode
    $result.TimedOut = $sim.TimedOut
    $result.Seconds = $sim.Seconds
    $escapedTop = [regex]::Escape($Top)
    $markers = [regex]::Matches($sim.Text, "(?m)^\s*(?:#\s*)?REGRESSION_PASS: $escapedTop\s*$").Count
    $finished = $sim.Text -match '(?m)^\s*(?:#\s*)?\*\* Note: \$finish\s*:'
    $returned = $sim.Text -match '(?m)^\s*(?:#\s*)?REGRESSION_RUN_RETURNED\s*$'
    if ($sim.TimedOut) { $result.Reason = 'HOST_TIMEOUT' }
    elseif (Has-ToolError $sim.Text) { $result.Reason = 'HDL_OR_TOOL_ERROR' }
    elseif ($sim.ExitCode -ne 0) { $result.Reason = 'NONZERO_EXIT' }
    elseif (!$returned) { $result.Reason = 'UNEXPECTED_EXIT' }
    elseif (!$finished) { $result.Reason = 'SIM_TIME_LIMIT_OR_NO_FINISH' }
    elseif ($markers -ne 1) { $result.Reason = 'MISSING_OR_DUPLICATE_COMPLETION' }
    else { $result.Status = 'PASS'; $result.Reason = 'COMPLETED' }
    [pscustomobject]$result
}

$results = @()
if ($SelfTest) {
    $fixtures = @(
        @{ Top='runner_pass'; Expected='COMPLETED'; Body='initial begin #1; $display("REGRESSION_PASS: runner_pass"); $finish; end' },
        @{ Top='runner_fatal'; Expected='HDL_OR_TOOL_ERROR'; Body='initial begin #1; $fatal(1,"controlled fatal"); end' },
        @{ Top='runner_error'; Expected='HDL_OR_TOOL_ERROR'; Body='initial begin #1; $error("controlled error"); $display("REGRESSION_PASS: runner_error"); $finish; end' },
        @{ Top='runner_late_fatal'; Expected='HDL_OR_TOOL_ERROR'; Body='initial begin #1; $display("REGRESSION_PASS: runner_late_fatal"); #1; $fatal(1,"failure after marker"); end' },
        @{ Top='runner_no_marker'; Expected='MISSING_OR_DUPLICATE_COMPLETION'; Body='initial begin #1; $finish; end' },
        @{ Top='runner_duplicate'; Expected='MISSING_OR_DUPLICATE_COMPLETION'; Body='initial begin #1; $display("REGRESSION_PASS: runner_duplicate"); $display("REGRESSION_PASS: runner_duplicate"); $finish; end' },
        @{ Top='runner_sim_timeout'; Expected='SIM_TIME_LIMIT_OR_NO_FINISH'; Body='reg clk=0; always #1 clk=~clk;' },
        @{ Top='runner_host_timeout'; Expected='HOST_TIMEOUT'; Body='integer fd; initial begin fd=$fopen("NUL","w"); forever $fdisplay(fd,"spin"); end' },
        @{ Top='runner_compile_error'; Expected='BUILD_ERROR'; Body='this is deliberately invalid SystemVerilog;' }
    )
    foreach ($fixture in $fixtures) {
        $source = Join-Path $runDir ($fixture.Top + '.sv')
        ([char]96 + 'timescale 1ns/1ps' + [Environment]::NewLine + 'module ' + $fixture.Top + '; ' + $fixture.Body + ' endmodule') |
            Set-Content -LiteralPath $source -Encoding ASCII
        $limit = if ($fixture.Top -eq 'runner_host_timeout') { 15 } else { $WallTimeoutSeconds }
        $item = Run-One $fixture.Top @($source) 100 $limit
        $item | Add-Member NoteProperty ExpectedReason $fixture.Expected
        $evidence = $true
        $processLog = Join-Path $item.Directory 'process.log'
        if ($fixture.Top -in @('runner_fatal','runner_error','runner_late_fatal')) {
            $probe = switch ($fixture.Top) {
                'runner_fatal' { 'controlled fatal' }
                'runner_error' { 'controlled error' }
                'runner_late_fatal' { 'failure after marker' }
            }
            $evidence = (Test-Path -LiteralPath $processLog) -and
                ((Get-Content -LiteralPath $processLog -Raw) -match [regex]::Escape($probe))
        }
        $item | Add-Member NoteProperty SelfTestOK (($item.Reason -eq $fixture.Expected) -and $evidence)
        $results += $item
        Write-Host ("SELFTEST {0}: actual={1} expected={2} matched={3}" -f $item.Test,$item.Reason,$item.ExpectedReason,$item.SelfTestOK)
    }
}
else {
    $rtlPaths = @($rtl | ForEach-Object { Join-Path (Join-Path $project 'src') $_ })
    foreach ($test in $Tests) {
        $sources = $rtlPaths + @(Join-Path (Join-Path $project 'tb') "$test.sv")
        $item = Run-One $test $sources $SimLimitNs $WallTimeoutSeconds
        $results += $item
        Write-Host ("{0}: {1} ({2})" -f $item.Test,$item.Status,$item.Reason)
    }
}
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDir 'summary.json') -Encoding ASCII
$results | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runDir 'summary.csv')
$changed = @()
foreach ($path in $before.Keys) {
    if (!(Test-Path -LiteralPath $path) -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $before[$path]) { $changed += $path }
}
if ($changed.Count -gt 0) { throw "Protected files changed: $($changed -join ', ')" }
Write-Host "Protected RTL/library/original scripts: unchanged"
Write-Host "Results: $runDir"
if ($SelfTest) {
    if (@($results | Where-Object { !$_.SelfTestOK }).Count -gt 0) { exit 1 }
}
elseif (@($results | Where-Object Status -ne 'PASS').Count -gt 0) { exit 1 }
exit 0
