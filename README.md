# Transparent, Post-Quantum Anonymous Set Membership from FRI-STARKs over BabyBear and Mersenne-31

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21264992.svg)](https://doi.org/10.5281/zenodo.21264992)

Reproduction package for the construction-and-analysis note of the same title.

**Author:** Enoch Kuskoff, Enkom Tech, `en.cipher@enkom.tech`

This repository bundles the paper with everything needed to rebuild and verify its claims: the
open-source implementation of both field instantiations, the parameter and soundness derivations, the
in-circuit audits, and the benchmark harness behind the measured comparison.

> **Status.** This is a construction-and-analysis note, not a claim of proven security. Two questions
> are left open and stated as such in the paper: O1 for Arm A (the `GF(p²)`-state Poseidon
> round-count parameterization) and O4 (the formal zero-knowledge simulator's masking-degree budget,
> shared by both arms). The rest of the work is implemented and reproducible from this repository: the
> construction, the parameters, the proof-system soundness characterization, and the measured costs.

## Layout

```
.
├── paper/                # the paper: LaTeX + Markdown source and the built PDF
│   └── *.tex  *.md  *.pdf
├── artifact/
│   ├── libQ/             # git submodule: github.com/Enkom-Tech/libQ @ v0.0.8 (the implementation)
│   └── README.md         # what in libQ backs which part of the paper
├── verify.sh             # one-command build-and-verify (Linux/macOS)
├── verify.ps1            # same, for Windows / PowerShell
├── .github/workflows/    # CI: runs the verification on every push
├── REPRODUCE.md          # claim, evidence, and command, step by step
├── LICENSE               # CC BY 4.0 (paper text + this repo's prose)
└── README.md
```

The implementation is included as a pinned git submodule of [`libQ`](https://github.com/Enkom-Tech/libQ)
(Apache-2.0) rather than a partial copy, because `lib-q-zkp` builds against the `libQ` Cargo workspace
(edition 2024, Rust >= 1.96) and does not compile in isolation.

## Quick start

Clone with the artifact submodule, then run one script. It initializes the submodule if needed,
checks the toolchain, and runs the construction, under-constraint audit, zero-knowledge, and soundness
tests that back the paper.

```sh
git clone --recurse-submodules https://github.com/En-Cipher/transparent-pq-anonymous-membership
cd transparent-pq-anonymous-membership
./verify.sh          # quick: build + all functional/audit/ZK/soundness tests
./verify.sh full     # also runs the Section 5.4 measurement harnesses (slow)
```

Windows / PowerShell: `./verify.ps1` (or `./verify.ps1 full`). The only prerequisite is
[Rust >= 1.96](https://rustup.rs) (edition 2024); the script handles the rest. The same checks run in
CI on every push (`.github/workflows/verify.yml`).

The built PDF is already included in `paper/`. Rebuilding it is optional, only to regenerate it from
source, and needs a LaTeX install: `cd paper && latexmk -pdf transparent-anonymous-membership-stark-eprint-draft-v0.tex`.

See [REPRODUCE.md](REPRODUCE.md) for the full claim-by-claim verification map and
[artifact/README.md](artifact/README.md) for the file-level pointers into `libQ`.

## Claim to evidence (summary)

| Paper section | Claim | Backed by (in `artifact/libQ/lib-q-zkp`) |
|---|---|---|
| §3-4 | Shared in-circuit gadgets (sponge, Merkle threading, hash) | `src/air/wide_sponge.rs`, `wide_merkle_path.rs`, `wide_hash.rs`; `tests/air_integration.rs` |
| §3-4, §5.1 | Arm A membership AIR (GF(p²)/Mersenne-31, α=5) | `src/air/unlinkable_membership.rs`, `src/air/poseidon_gadget.rs`, `src/stark.rs`, `src/merkle.rs` |
| §3-4, §5.2 | Arm B membership AIR (BabyBear/Poseidon2, α=7) | `src/air/unlinkable_membership_baby_bear.rs`, `src/air/poseidon2_gadget.rs`, `src/stark_baby_bear.rs`, `src/merkle_baby_bear.rs` |
| §4 | Structural / under-constraint audit finds no exploitable relation | `tests/ip_soundness_tests.rs`, `tests/unlinkable_membership_tests.rs`; `docs/membership-arm-b-redteam.md` |
| §5.1, §6 (O1) | Arm A `GF(p²)` round counts clear published bounds (about 2x); subfield defense | `docs/membership-arm-a-soundness-params.md`, `docs/membership-adr113-freeze-gate-review.md` |
| §5.2, §6 (O1) | Arm B = deployed BabyBear Poseidon2; O1 reduces to a citation | `docs/membership-arm-b-soundness-params.md`, `-obligation-packet.md`, `-poseidon2-gadget-design.md` |
| §6 (O2/O3) | Sponge collision/preimage and domain separation | `tests/security_parameter_tests.rs`; the soundness-params docs |
| §6 (O4) | ZK implemented (hiding PCS); formal simulator open | `tests/zero_knowledge_tests.rs` |
| §6.5 | 128-bit-PQ proof-system soundness (challenge field) | `tests/security_parameter_tests.rs`; soundness-params docs |
| §5.4 | Arm B about 14-18x smaller proofs, about 16-17x faster verify, equal security | `benches/zkp_benchmarks.rs`; `docs/membership-arm-b-measurement.md` |

## License

The paper and this repository's prose are released under CC BY 4.0 (see [LICENSE](LICENSE)). The
bundled `libQ` submodule is licensed separately under Apache-2.0 (see its own `LICENSE`).

## How to cite

Enoch Kuskoff. *Transparent, Post-Quantum Anonymous Set Membership from FRI-STARKs over BabyBear and
Mersenne-31.* Enkom Tech, 2026. https://doi.org/10.5281/zenodo.21264992

```bibtex
@misc{kuskoff2026membership,
  author    = {Kuskoff, Enoch},
  title     = {Transparent, Post-Quantum Anonymous Set Membership from FRI-STARKs over BabyBear and Mersenne-31},
  year      = {2026},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.21264992},
  url       = {https://doi.org/10.5281/zenodo.21264992}
}
```
