# Reproducing and verifying the paper

This document maps every claim in the paper to the file, test, or benchmark in the bundled
[`libQ`](https://github.com/Enkom-Tech/libQ) submodule that backs it, with the exact command to run.
Nothing here requires private material.

## 0. Prerequisites

- Rust >= 1.96 (edition 2024). Install with `rustup toolchain install 1.96.0` or newer.
- A C toolchain (transitive build deps).
- For rebuilding the paper PDF only: a LaTeX distribution with `latexmk` (TeX Live / MiKTeX).

```sh
git clone --recurse-submodules https://github.com/En-Cipher/transparent-pq-anonymous-membership
cd transparent-pq-anonymous-membership/artifact/libQ
# If you cloned without --recurse-submodules:  git submodule update --init  (from repo root)
```

The submodule is pinned to commit `34cb3f0` (`libQ`, tag `v0.0.8`). Verify:

```sh
git -C artifact/libQ rev-parse HEAD     # → 34cb3f04d871960162ee64a89a432f10de7ef826
```

## 1. Construction and in-circuit audit (§3-4)

The membership AIR and the structural / under-constraint audit (sponge, Merkle threading, same-`t`
leaf/nullifier binding, padding rows, public binding, degree/FRI config) are exercised by:

```sh
cargo test --release -p lib-q-zkp                       # full suite
cargo test --release -p lib-q-zkp --test air_integration
cargo test --release -p lib-q-zkp --test ip_soundness_tests
cargo test --release -p lib-q-zkp --test unlinkable_membership_tests
```

These include the negative-proof matrix (mutated witnesses / constraints must fail to verify), which
is the runnable form of the paper's claim (§4) that a malicious prover cannot make the AIR accept an
invalid statement.

## 2. Zero-knowledge (§6, O4: implemented, formal simulator open)

```sh
cargo test --release -p lib-q-zkp --test zero_knowledge_tests
```

This covers the hiding-PCS instantiation and the two blinding-randomness fixes (L1 CSPRNG salts, L2
fresh >=256-bit seeds) described in §6/O4. The formal simulator write-up (O4) is the open item: the
tests demonstrate the implemented ZK path, not a proof of the simulator's masking-degree budget.

## 3. Parameters and proof-system soundness (§5, §6, §6.5)

The 128-bit-PQ soundness characterization (challenge-field sizing, `log_blowup`, query count, PoW,
SHAKE256 binding) and the per-arm parameter sets are derived in the docs and asserted in tests:

```sh
cargo test --release -p lib-q-zkp --test security_parameter_tests
```

Reading, not running, for the O1 round-count analysis:

- Arm A (`GF(p²)`-state): `artifact/libQ/lib-q-zkp/docs/membership-arm-a-soundness-params.md`,
  `docs/membership-adr113-freeze-gate-review.md`. These give the `8+60` round count against the
  published bounds, and the subfield-descent defense via generic round constants (the paper's O1
  crux for review).
- Arm B (BabyBear Poseidon2): `docs/membership-arm-b-soundness-params.md`,
  `docs/membership-arm-b-obligation-packet.md`,
  `docs/membership-arm-b-poseidon2-gadget-design.md`. Here O1 is conformance to the deployed Plonky3
  / SP1 parameter set.
- Adversarial self-check against the 2022-2026 algebraic-attack wave:
  `docs/membership-arm-b-redteam.md`.

## 4. Measured cost, the Section 5.4 table

The numbers are produced by two `#[ignore]`d measurement harnesses in
`lib-q-zkp/src/stark_baby_bear.rs` (`tests::measure_arm_a`, `tests::measure_arm_b`):

```sh
cargo test --release -p lib-q-zkp --lib stark_baby_bear::tests::measure_arm_b -- --ignored --nocapture
cargo test --release -p lib-q-zkp --lib stark_baby_bear::tests::measure_arm_a -- --ignored --nocapture
```

- The default is single-threaded (the `parallel` / rayon feature is off), which is the configuration
  the paper reports.
- Prove / verify times are the median of 5; proof size is `postcard::to_allocvec(proof).len()`.
- Full methodology and the per-depth (4/8/16/32, transparent + ZK) breakdown:
  `artifact/libQ/lib-q-zkp/docs/membership-arm-b-measurement.md`.

Environment the paper measured on: AMD Ryzen 9 5900X (12C/24T), Windows 10 IoT x86_64, Rust 1.96.
Absolute timings will differ on other hardware; the cross-arm ratios (about 14-18x proof size, about
16-17x verify) are the reproducible, hardware-independent result. Enabling the `parallel` feature
lowers prove wall-clock and is not the reported configuration.

## 5. Rebuild the paper PDF

```sh
cd paper
latexmk -pdf transparent-anonymous-membership-stark-eprint-draft-v0.tex
```

## What is not settled (by design)

- O1 (Arm A): the `GF(p²)`-state round-count parameterization. Engineering arguments clear the
  published bounds, but the off-envelope state is an open question for expert review. Arm B avoids it.
- O4 (both arms): a formal zero-knowledge simulator with a confirmed masking-degree budget.

The paper states both explicitly. This package lets a reviewer reach the same boundary by building and
running the code, rather than taking the construction and measurements on trust.
