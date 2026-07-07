# One-command verification of the paper's claims (PowerShell).
#   ./verify.ps1          quick: construction + audit + ZK + soundness tests
#   ./verify.ps1 full     also runs the Section 5.4 measurement harnesses (slow)
[CmdletBinding()]
param([ValidateSet('quick','full')][string]$Mode = 'quick')
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

# 1. ensure the implementation submodule is materialized
if (-not (Test-Path "$Root/artifact/libQ/lib-q-zkp/Cargo.toml")) {
    Write-Host "==> initializing libQ submodule (github.com/Enkom-Tech/libQ @ pinned commit)"
    git -C $Root submodule update --init artifact/libQ
}

# 2. toolchain
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Error "cargo not found. Install Rust >= 1.96 (edition 2024): https://rustup.rs"
}

Set-Location "$Root/artifact/libQ"
Write-Host "==> libQ @ $(git rev-parse --short HEAD)  |  $(cargo --version)"

Write-Host "==> [1/2] construction, under-constraint audit, zero-knowledge, soundness (cargo test --release)"
cargo test --release -p lib-q-zkp
if ($LASTEXITCODE -ne 0) { Write-Error "tests failed" }

if ($Mode -eq 'full') {
    Write-Host "==> [2/2] Section 5.4 measurement harnesses (single-thread; this is slow)"
    cargo test --release -p lib-q-zkp --lib stark_baby_bear::tests::measure_arm_b -- --ignored --nocapture
    if ($LASTEXITCODE -ne 0) { Write-Error "measure_arm_b failed" }
    cargo test --release -p lib-q-zkp --lib stark_baby_bear::tests::measure_arm_a -- --ignored --nocapture
    if ($LASTEXITCODE -ne 0) { Write-Error "measure_arm_a failed" }
} else {
    Write-Host "==> [2/2] skipped measurement harnesses (run './verify.ps1 full' to include §5.4)"
}

Write-Host ""
Write-Host "VERIFY OK"
