[CmdletBinding()]
param(
  [ValidateSet('chess-local', 'backgammon-local', 'chess-online', 'backgammon-online', 'full-smoke')]
  [string]$Scenario = 'full-smoke',
  [ValidateSet('smoke', 'nightly')]
  [string]$Profile = 'smoke',
  [string]$WorkspaceRoot = '',
  [string]$BackendUrl = 'http://localhost:8080',
  [int[]]$Seeds,
  [string]$RunId = '',
  [switch]$KeepGoing
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-FlutterExe {
  $preferred = 'C:\dev\flutter\bin\flutter.bat'
  if (Test-Path $preferred) {
    return $preferred
  }
  return 'flutter'
}

function New-RunId {
  return 'run_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
}

function New-SeedList {
  param(
    [int]$Count,
    [int[]]$ExplicitSeeds
  )
  if ($ExplicitSeeds -and $ExplicitSeeds.Count -gt 0) {
    return $ExplicitSeeds
  }

  $result = @()
  for ($i = 1; $i -le $Count; $i++) {
    $result += (1000 + $i)
  }
  return $result
}

function Invoke-DartSync {
  param(
    [string]$WorkingDirectory,
    [string[]]$Arguments,
    [string]$StdoutPath,
    [string]$StderrPath
  )

  $stdoutDir = Split-Path -Parent $StdoutPath
  $stderrDir = Split-Path -Parent $StderrPath
  New-Item -ItemType Directory -Path $stdoutDir -Force | Out-Null
  New-Item -ItemType Directory -Path $stderrDir -Force | Out-Null
  Push-Location $WorkingDirectory
  try {
    & $script:flutterExe @Arguments 1> $StdoutPath 2> $StderrPath
    return $LASTEXITCODE
  } finally {
    Pop-Location
  }
}

function Wait-ForReadyEvent {
  param(
    [string]$JsonlPath,
    [int]$TimeoutSeconds = 45
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    if (Test-Path $JsonlPath) {
      $lines = Get-Content -Path $JsonlPath -ErrorAction SilentlyContinue
      foreach ($line in $lines) {
        if ($line -match '"eventType"\s*:\s*"session_joined"' -or
            $line -match '"eventType"\s*:\s*"connection_state"') {
          return $true
        }
      }
    }
    Start-Sleep -Milliseconds 400
  }
  return $false
}

function Resolve-ProcessExitCode {
  param(
    [System.Diagnostics.Process]$Process,
    [string]$SessionLogPath
  )

  if ($null -ne $Process) {
    try {
      if (-not $Process.HasExited) {
        $Process.WaitForExit()
      }
      $Process.Refresh()
      return [int]$Process.ExitCode
    } catch {
      # Fall through to log-based resolution when process metadata is unavailable.
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($SessionLogPath) -and (Test-Path $SessionLogPath)) {
    $hasCompletion = Select-String `
      -Path $SessionLogPath `
      -Pattern '"eventType"\s*:\s*"session_complete"' `
      -Quiet `
      -ErrorAction SilentlyContinue
    if ($hasCompletion) {
      return 0
    }

    $hasCrash = Select-String `
      -Path $SessionLogPath `
      -Pattern '"eventType"\s*:\s*"crash"' `
      -Quiet `
      -ErrorAction SilentlyContinue
    if ($hasCrash) {
      return 1
    }
  }

  return $null
}

function Invoke-Analyzer {
  param(
    [string]$PrimaryPath,
    [string]$SecondaryPath,
    [string]$OutputDir,
    [int]$MinSessions,
    [double]$MinCompletionRate,
    [string]$ReproCommand
  )

  $args = @(
    'pub',
    'run',
    'bin/bughunt_analyzer.dart',
    "--primary=$PrimaryPath",
    "--output=$OutputDir",
    "--min-sessions=$MinSessions",
    "--min-completion-rate=$MinCompletionRate",
    "--repro=$ReproCommand"
  )
  if (-not [string]::IsNullOrWhiteSpace($SecondaryPath)) {
    $args += "--secondary=$SecondaryPath"
  }

  $stdout = Join-Path $OutputDir 'analyzer.stdout.log'
  $stderr = Join-Path $OutputDir 'analyzer.stderr.log'
  $exitCode = Invoke-DartSync `
    -WorkingDirectory $script:sharedRepo `
    -Arguments $args `
    -StdoutPath $stdout `
    -StderrPath $stderr
  return $exitCode
}

function Run-ChessLocal {
  param([int[]]$SeedList, [int]$RequiredSessions, [double]$MinCompletionRate)

  foreach ($seed in $SeedList) {
    $outDir = Join-Path $script:orchestratorRoot "chess\local\seed_$seed"
    $weirdLogPath = Join-Path $outDir 'weird.jsonl'
    $pgnPath = Join-Path $outDir 'pgn'
    $args = @(
      'pub',
      'run',
      'tool/ai_duel.dart',
      '--games=1',
      '--max-plies=240',
      "--seed=$seed",
      "--run-id=$script:RunId",
      "--log-file=$weirdLogPath",
      "--pgn-dir=$pgnPath"
    )
    $exitCode = Invoke-DartSync `
      -WorkingDirectory $script:chessRepo `
      -Arguments $args `
      -StdoutPath (Join-Path $outDir 'stdout.log') `
      -StderrPath (Join-Path $outDir 'stderr.log')
    if ($exitCode -ne 0) {
      throw "Chess local seed $seed failed with exit code $exitCode."
    }
  }

  $primary = Join-Path $script:artifactRoot "chess\ai\locala.jsonl"
  $analysisOut = Join-Path $script:orchestratorRoot 'analysis\chess_local'
  $analyzerExit = Invoke-Analyzer `
    -PrimaryPath $primary `
    -SecondaryPath '' `
    -OutputDir $analysisOut `
    -MinSessions $RequiredSessions `
    -MinCompletionRate $MinCompletionRate `
    -ReproCommand 'dart run tool/ai_duel.dart --games=1 --max-plies=240 --seed=<seed> --run-id=<runId>'
  if ($analyzerExit -ne 0) {
    throw "Chess local analyzer failed with exit code $analyzerExit."
  }
}

function Run-BackgammonLocal {
  param([int[]]$SeedList, [int]$RequiredSessions, [double]$MinCompletionRate)

  foreach ($seed in $SeedList) {
    $outDir = Join-Path $script:orchestratorRoot "backgammon\local\seed_$seed"
    $args = @(
      'pub',
      'run',
      'tool/sheshbesh_ai_duel.dart',
      '--games=1',
      "--seed=$seed",
      "--run-id=$script:RunId"
    )
    $exitCode = Invoke-DartSync `
      -WorkingDirectory $script:backgammonRepo `
      -Arguments $args `
      -StdoutPath (Join-Path $outDir 'stdout.log') `
      -StderrPath (Join-Path $outDir 'stderr.log')
    if ($exitCode -ne 0) {
      throw "Backgammon local seed $seed failed with exit code $exitCode."
    }
  }

  $primary = Join-Path $script:artifactRoot "backgammon\ai\locala.jsonl"
  $analysisOut = Join-Path $script:orchestratorRoot 'analysis\backgammon_local'
  $analyzerExit = Invoke-Analyzer `
    -PrimaryPath $primary `
    -SecondaryPath '' `
    -OutputDir $analysisOut `
    -MinSessions $RequiredSessions `
    -MinCompletionRate $MinCompletionRate `
    -ReproCommand 'dart run tool/sheshbesh_ai_duel.dart --games=1 --seed=<seed> --run-id=<runId>'
  if ($analyzerExit -ne 0) {
    throw "Backgammon local analyzer failed with exit code $analyzerExit."
  }
}

function Run-ChessOnline {
  param([int[]]$SeedList, [int]$RequiredSessions, [double]$MinCompletionRate)

  $aggregateHostLog = Join-Path $script:artifactRoot 'chess\online\host.jsonl'
  $aggregateClientLog = Join-Path $script:artifactRoot 'chess\online\client.jsonl'
  New-Item -ItemType Directory -Path (Split-Path -Parent $aggregateHostLog) -Force | Out-Null
  if (Test-Path $aggregateHostLog) { Remove-Item $aggregateHostLog -Force }
  if (Test-Path $aggregateClientLog) { Remove-Item $aggregateClientLog -Force }

  foreach ($seed in $SeedList) {
    $seedDir = Join-Path $script:orchestratorRoot "chess\online\seed_$seed"
    New-Item -ItemType Directory -Path $seedDir -Force | Out-Null
    $seedHostLog = Join-Path $seedDir 'host.session.jsonl'
    $seedClientLog = Join-Path $seedDir 'client.session.jsonl'

    $hostArgs = @(
      'pub',
      'run',
      'tool/network_ai_duel_client.dart',
      "--backend-url=$script:BackendUrl",
      "--name=ChessHost-$seed",
      '--cooldown-seconds=0',
      "--seed=$seed",
      "--run-id=$script:RunId",
      '--role=host',
      "--log-file=$seedHostLog"
    )
    $hostProc = Start-Process `
      -FilePath $script:flutterExe `
      -ArgumentList $hostArgs `
      -WorkingDirectory $script:chessRepo `
      -NoNewWindow `
      -PassThru `
      -RedirectStandardOutput (Join-Path $seedDir 'host.stdout.log') `
      -RedirectStandardError (Join-Path $seedDir 'host.stderr.log')

    $ready = Wait-ForReadyEvent -JsonlPath $seedHostLog -TimeoutSeconds 45
    if (-not $ready) {
      try { if (-not $hostProc.HasExited) { $hostProc.Kill() } } catch {}
      throw "Chess online host did not emit a ready event for seed $seed."
    }

    $clientArgs = @(
      'pub',
      'run',
      'tool/network_ai_duel_client.dart',
      "--backend-url=$script:BackendUrl",
      "--name=ChessClient-$seed",
      '--cooldown-seconds=0',
      "--seed=$seed",
      "--run-id=$script:RunId",
      '--role=client',
      "--log-file=$seedClientLog"
    )
    $clientProc = Start-Process `
      -FilePath $script:flutterExe `
      -ArgumentList $clientArgs `
      -WorkingDirectory $script:chessRepo `
      -NoNewWindow `
      -PassThru `
      -RedirectStandardOutput (Join-Path $seedDir 'client.stdout.log') `
      -RedirectStandardError (Join-Path $seedDir 'client.stderr.log')

    $hostExitCode = Resolve-ProcessExitCode -Process $hostProc -SessionLogPath $seedHostLog
    $clientExitCode = Resolve-ProcessExitCode -Process $clientProc -SessionLogPath $seedClientLog
    if ($null -eq $hostExitCode -or $hostExitCode -ne 0) {
      throw "Chess online host failed for seed $seed with exit code $hostExitCode."
    }
    if ($null -eq $clientExitCode -or $clientExitCode -ne 0) {
      throw "Chess online client failed for seed $seed with exit code $clientExitCode."
    }
    if (Test-Path $seedHostLog) {
      Get-Content -Path $seedHostLog | Add-Content -Path $aggregateHostLog
    }
    if (Test-Path $seedClientLog) {
      Get-Content -Path $seedClientLog | Add-Content -Path $aggregateClientLog
    }
  }

  $analysisOut = Join-Path $script:orchestratorRoot 'analysis\chess_online'
  $analyzerExit = Invoke-Analyzer `
    -PrimaryPath $aggregateHostLog `
    -SecondaryPath $aggregateClientLog `
    -OutputDir $analysisOut `
    -MinSessions $RequiredSessions `
    -MinCompletionRate $MinCompletionRate `
    -ReproCommand 'dart run tool/network_ai_duel_client.dart --backend-url=<url> --role=host|client --seed=<seed> --run-id=<runId>'
  if ($analyzerExit -ne 0) {
    throw "Chess online analyzer failed with exit code $analyzerExit."
  }
}

function Run-BackgammonOnline {
  param([int[]]$SeedList, [int]$RequiredSessions, [double]$MinCompletionRate)

  $aggregateHostLog = Join-Path $script:artifactRoot 'backgammon\online\host.jsonl'
  $aggregateClientLog = Join-Path $script:artifactRoot 'backgammon\online\client.jsonl'
  New-Item -ItemType Directory -Path (Split-Path -Parent $aggregateHostLog) -Force | Out-Null
  if (Test-Path $aggregateHostLog) { Remove-Item $aggregateHostLog -Force }
  if (Test-Path $aggregateClientLog) { Remove-Item $aggregateClientLog -Force }

  foreach ($seed in $SeedList) {
    $seedDir = Join-Path $script:orchestratorRoot "backgammon\online\seed_$seed"
    New-Item -ItemType Directory -Path $seedDir -Force | Out-Null
    $seedHostLog = Join-Path $seedDir 'host.session.jsonl'
    $seedClientLog = Join-Path $seedDir 'client.session.jsonl'

    $hostArgs = @(
      'pub',
      'run',
      'tool/network_ai_duel_client.dart',
      "--backend-url=$script:BackendUrl",
      "--name=BackgammonHost-$seed",
      '--cooldown-seconds=0',
      "--seed=$seed",
      '--max-seconds=120',
      "--run-id=$script:RunId",
      '--role=host',
      "--log-file=$seedHostLog"
    )
    $hostProc = Start-Process `
      -FilePath $script:flutterExe `
      -ArgumentList $hostArgs `
      -WorkingDirectory $script:backgammonRepo `
      -NoNewWindow `
      -PassThru `
      -RedirectStandardOutput (Join-Path $seedDir 'host.stdout.log') `
      -RedirectStandardError (Join-Path $seedDir 'host.stderr.log')

    $ready = Wait-ForReadyEvent -JsonlPath $seedHostLog -TimeoutSeconds 45
    if (-not $ready) {
      try { if (-not $hostProc.HasExited) { $hostProc.Kill() } } catch {}
      throw "Backgammon online host did not emit a ready event for seed $seed."
    }

    $clientArgs = @(
      'pub',
      'run',
      'tool/network_ai_duel_client.dart',
      "--backend-url=$script:BackendUrl",
      "--name=BackgammonClient-$seed",
      '--cooldown-seconds=0',
      "--seed=$seed",
      '--max-seconds=120',
      "--run-id=$script:RunId",
      '--role=client',
      "--log-file=$seedClientLog"
    )
    $clientProc = Start-Process `
      -FilePath $script:flutterExe `
      -ArgumentList $clientArgs `
      -WorkingDirectory $script:backgammonRepo `
      -NoNewWindow `
      -PassThru `
      -RedirectStandardOutput (Join-Path $seedDir 'client.stdout.log') `
      -RedirectStandardError (Join-Path $seedDir 'client.stderr.log')

    $hostExitCode = Resolve-ProcessExitCode -Process $hostProc -SessionLogPath $seedHostLog
    $clientExitCode = Resolve-ProcessExitCode -Process $clientProc -SessionLogPath $seedClientLog
    if ($null -eq $hostExitCode -or $hostExitCode -ne 0) {
      throw "Backgammon online host failed for seed $seed with exit code $hostExitCode."
    }
    if ($null -eq $clientExitCode -or $clientExitCode -ne 0) {
      throw "Backgammon online client failed for seed $seed with exit code $clientExitCode."
    }
    if (Test-Path $seedHostLog) {
      Get-Content -Path $seedHostLog | Add-Content -Path $aggregateHostLog
    }
    if (Test-Path $seedClientLog) {
      Get-Content -Path $seedClientLog | Add-Content -Path $aggregateClientLog
    }
  }

  $analysisOut = Join-Path $script:orchestratorRoot 'analysis\backgammon_online'
  $analyzerExit = Invoke-Analyzer `
    -PrimaryPath $aggregateHostLog `
    -SecondaryPath $aggregateClientLog `
    -OutputDir $analysisOut `
    -MinSessions $RequiredSessions `
    -MinCompletionRate $MinCompletionRate `
    -ReproCommand 'dart run tool/network_ai_duel_client.dart --backend-url=<url> --role=host|client --seed=<seed> --run-id=<runId>'
  if ($analyzerExit -ne 0) {
    throw "Backgammon online analyzer failed with exit code $analyzerExit."
  }
}

$script:flutterExe = Get-FlutterExe
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $WorkspaceRoot = (Resolve-Path (Join-Path $scriptRoot '..\..')).Path
}
$script:sharedRepo = Join-Path $WorkspaceRoot 'bullethole-shared'
$script:chessRepo = Join-Path $WorkspaceRoot 'bulletholechess'
$script:backgammonRepo = Join-Path $WorkspaceRoot 'bulletholebackgammon'
$script:BackendUrl = $BackendUrl
$script:RunId = if ([string]::IsNullOrWhiteSpace($RunId)) { New-RunId } else { $RunId }
$script:artifactRoot = Join-Path $WorkspaceRoot "artifacts\bughunt\$script:RunId"
$script:orchestratorRoot = Join-Path $script:artifactRoot '_orchestrator'
New-Item -ItemType Directory -Path $script:orchestratorRoot -Force | Out-Null

$env:BULLETHOLE_LOG_ROOT = $WorkspaceRoot
$env:BULLETHOLE_BUGHUNT_RUN_ID = $script:RunId

$localSessions = if ($Profile -eq 'nightly') { 100 } else { 10 }
$onlineSessions = if ($Profile -eq 'nightly') { 30 } else { 5 }
$hasExplicitSeeds = ($PSBoundParameters.ContainsKey('Seeds') -and $Seeds.Count -gt 0)
if ($hasExplicitSeeds) {
  $localSessions = $Seeds.Count
  $onlineSessions = $Seeds.Count
}
$minCompletionRate = if ($Profile -eq 'nightly') { 0.99 } else { 1.0 }

$localSeeds = New-SeedList -Count $localSessions -ExplicitSeeds $Seeds
$onlineSeeds = New-SeedList -Count $onlineSessions -ExplicitSeeds $Seeds

$script:failures = @()

function Invoke-Step {
  param([scriptblock]$Body, [string]$Name)
  try {
    & $Body
    Write-Host "[PASS] $Name"
  } catch {
    $script:failures += "${Name}: $($_.Exception.Message)"
    Write-Host "[FAIL] ${Name}: $($_.Exception.Message)" -ForegroundColor Red
    if (-not $KeepGoing) {
      throw
    }
  }
}

if ($Scenario -eq 'chess-local' -or $Scenario -eq 'full-smoke') {
  Invoke-Step -Name 'chess-local' -Body {
    Run-ChessLocal -SeedList $localSeeds -RequiredSessions $localSessions -MinCompletionRate $minCompletionRate
  }
}
if ($Scenario -eq 'backgammon-local' -or $Scenario -eq 'full-smoke') {
  Invoke-Step -Name 'backgammon-local' -Body {
    Run-BackgammonLocal -SeedList $localSeeds -RequiredSessions $localSessions -MinCompletionRate $minCompletionRate
  }
}
if ($Scenario -eq 'chess-online' -or $Scenario -eq 'full-smoke') {
  Invoke-Step -Name 'chess-online' -Body {
    Run-ChessOnline -SeedList $onlineSeeds -RequiredSessions $onlineSessions -MinCompletionRate $minCompletionRate
  }
}
if ($Scenario -eq 'backgammon-online' -or $Scenario -eq 'full-smoke') {
  Invoke-Step -Name 'backgammon-online' -Body {
    Run-BackgammonOnline -SeedList $onlineSeeds -RequiredSessions $onlineSessions -MinCompletionRate $minCompletionRate
  }
}

$summaryPath = Join-Path $script:orchestratorRoot 'run_summary.md'
$summaryLines = @(
  '# Bughunt Matrix Run',
  '',
  "- runId: $script:RunId",
  "- scenario: $Scenario",
  "- profile: $Profile",
  "- backendUrl: $BackendUrl",
  "- artifactRoot: $script:artifactRoot"
)
if ($script:failures.Count -gt 0) {
  $summaryLines += ''
  $summaryLines += '## Failures'
  foreach ($failure in $script:failures) {
    $summaryLines += "- $failure"
  }
} else {
  $summaryLines += ''
  $summaryLines += 'All selected matrix lanes passed.'
}
Set-Content -Path $summaryPath -Value $summaryLines -Encoding UTF8

Write-Host "Run summary: $summaryPath"
if ($script:failures.Count -gt 0) {
  exit 2
}
