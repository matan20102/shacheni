# Builds the NAYBOR preview for the web and serves it locally.
# Pass -Config config\building-dev.json to use the connected app.
param(
  [string]$Config = '',
  [int]$Port = 8080
)

Set-Location $PSScriptRoot

$defines = @()
if ($Config) { $defines += "--dart-define-from-file=$Config" }

flutter build web --release --no-wasm-dry-run @defines --output=build\web_demo
if ($LASTEXITCODE -ne 0) { Write-Error 'Build failed'; exit 1 }

Write-Host "Serving on http://localhost:$Port  (Ctrl+C to stop)"
Start-Process "http://localhost:$Port"
python -m http.server $Port --directory build\web_demo
