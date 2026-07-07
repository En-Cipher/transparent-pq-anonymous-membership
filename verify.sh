#!/usr/bin/env bash
# One-command verification of the paper's claims.
#   ./verify.sh         quick: construction + audit + ZK + soundness tests
#   ./verify.sh full    also runs the Section 5.4 measurement harnesses (slow)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-quick}"

# 1. ensure the implementation submodule is materialized
if [ ! -f "$ROOT/artifact/libQ/lib-q-zkp/Cargo.toml" ]; then
  echo "==> initializing libQ submodule (github.com/Enkom-Tech/libQ @ pinned commit)"
  git -C "$ROOT" submodule update --init artifact/libQ
fi

# 2. toolchain
command -v cargo >/dev/null || {
  echo "ERROR: cargo not found. Install Rust >= 1.96 (edition 2024): https://rustup.rs" >&2
  exit 1
}

cd "$ROOT/artifact/libQ"
echo "==> libQ @ $(git rev-parse --short HEAD)  |  $(cargo --version)"

echo "==> [1/2] construction, under-constraint audit, zero-knowledge, soundness (cargo test --release)"
cargo test --release -p lib-q-zkp

if [ "$MODE" = "full" ]; then
  echo "==> [2/2] Section 5.4 measurement harnesses (single-thread; this is slow)"
  cargo test --release -p lib-q-zkp --lib stark_baby_bear::tests::measure_arm_b -- --ignored --nocapture
  cargo test --release -p lib-q-zkp --lib stark_baby_bear::tests::measure_arm_a -- --ignored --nocapture
else
  echo "==> [2/2] skipped measurement harnesses (run './verify.sh full' to include §5.4)"
fi

echo
echo "VERIFY OK"
