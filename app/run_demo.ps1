# Builds the Shacheni prototype for the web and serves it locally (no debugger needed).
# Usage (from the app folder):   .\run_demo.ps1            -> Hebrew/English by device language
#                                .\run_demo.ps1 -SkipOnboarding -Locale en
param(
  [switch]$SkipOnboarding,
  [ValidateSet('', 'he', 'en')][string]$Locale = '',
  [int]$Port = 8080
)

$env:Path = "C:\src\flutter\bin;" + $env:Path
Set-Location $PSScriptRoot

$defines = @()
if ($SkipOnboarding) { $defines += '--dart-define=DEMO_SIGNED_IN=true' }
if ($Locale) { $defines += "--dart-define=DEMO_LOCALE=$Locale" }
if (Test-Path config\dev.json) { $defines += '--dart-define-from-file=config/dev.json' }  # Supabase dev project

flutter build web --release --no-wasm-dry-run @defines --output=build\web_demo
if ($LASTEXITCODE -ne 0) { Write-Error 'Build failed'; exit 1 }

Write-Host "Serving on http://localhost:$Port  (Ctrl+C to stop)"
Start-Process "http://localhost:$Port"
python -m http.server $Port --directory build\web_demo
