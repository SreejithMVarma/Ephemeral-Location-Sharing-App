Param(
  [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot ".."))
)

$backendPath = Join-Path $WorkspaceRoot "apps/backend"
$mobilePath = Join-Path $WorkspaceRoot "apps/mobile"

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  throw "adb was not found on PATH"
}

$devices = & adb devices -l
$deviceSerial = $devices |
  Select-String -Pattern '^([A-Za-z0-9._-]+)\s+device\b' |
  ForEach-Object { $_.Matches[0].Groups[1].Value } |
  Where-Object { $_ -notlike 'emulator-*' } |
  Select-Object -First 1

if (-not $deviceSerial) {
  throw "No physical Android device found. Connect the Vivo phone before running dev:phone."
}

& adb -s $deviceSerial reverse tcp:8000 tcp:8000 | Out-Host

$backendListening = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if (-not $backendListening) {
  Start-Process powershell -WorkingDirectory $backendPath -ArgumentList @(
    '-NoExit',
    '-Command',
    'poetry run uvicorn src.main:app --reload --port 8000'
  ) | Out-Null
}

Push-Location $mobilePath
try {
  flutter run -d $deviceSerial --dart-define-from-file=env/dev.phone.json
} finally {
  Pop-Location
}