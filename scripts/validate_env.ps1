Param(
  [string]$ExampleFile = ".env.example",
  [string]$TargetFile = ".env.development"
)

if (-not (Test-Path $ExampleFile)) {
  throw "Missing $ExampleFile"
}

if (-not (Test-Path $TargetFile)) {
  throw "Missing $TargetFile"
}

$exampleKeys = Get-Content $ExampleFile |
  Where-Object { $_ -and -not $_.StartsWith("#") } |
  ForEach-Object { ($_ -split "=", 2)[0].Trim() } |
  Where-Object { $_ }

$targetKeys = Get-Content $TargetFile |
  Where-Object { $_ -and -not $_.StartsWith("#") } |
  ForEach-Object { ($_ -split "=", 2)[0].Trim() } |
  Where-Object { $_ }

$missing = $exampleKeys | Where-Object { $_ -notin $targetKeys }
if ($missing.Count -gt 0) {
  throw "Missing keys in ${TargetFile}: $($missing -join ', ')"
}

Write-Host "Environment validation passed for $TargetFile"
