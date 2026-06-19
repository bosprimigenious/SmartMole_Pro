# SmartMole Pro - full build: MD -> Typst -> PDF
# Usage: cd docs && python compile_all.py

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
python (Join-Path $PSScriptRoot "compile_all.py")
exit $LASTEXITCODE
