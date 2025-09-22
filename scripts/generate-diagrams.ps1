param(
  [string]$SourceDir = "$PSScriptRoot/../docs/diagrams",
  [string]$OutDir = "$PSScriptRoot/../docs/diagrams/png",
  [switch]$Install
)

if ($Install) {
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { throw 'npm not found in PATH'; }
  Write-Host 'Installing mermaid-cli globally...'
  npm install -g @mermaid-js/mermaid-cli | Out-Null
}

if (-not (Get-Command mmdc -ErrorAction SilentlyContinue)) {
  Write-Warning 'mmdc not found. Run with -Install or ensure mermaid-cli is in PATH.'
  if (-not $Install) { throw 'mmdc command missing'; }
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

Get-ChildItem -Path $SourceDir -Filter *.mmd | ForEach-Object {
  $outFile = Join-Path $OutDir ("{0}.png" -f $_.BaseName)
  Write-Host "Generating single mermaid chart: $($_.Name)" -ForegroundColor Cyan
  $stderr = New-TemporaryFile
  $start = Get-Date
  & mmdc -i $_.FullName -o $outFile --backgroundColor transparent 2> $stderr.FullName
  $exit = $LASTEXITCODE
  $elapsed = (Get-Date) - $start
  if ((Test-Path $outFile) -and ($exit -eq 0)) {
    Write-Host "Generated $outFile ($([int]$elapsed.TotalMilliseconds) ms)" -ForegroundColor Green
  } else {
    Write-Warning "Failed to generate $outFile (exit $exit)"
    $errText = Get-Content $stderr.FullName | Out-String
    if ($errText.Trim().Length -gt 0) {
      Write-Host "---- stderr for $($_.Name) ----" -ForegroundColor Yellow
      Write-Host $errText
      Write-Host "---- end stderr ----" -ForegroundColor Yellow
    }
  }
  Remove-Item $stderr -ErrorAction SilentlyContinue
}
