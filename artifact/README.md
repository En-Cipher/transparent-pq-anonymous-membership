# Artifact: the `libQ` implementation

The paper's implementation is included as a git submodule pinned to a specific commit, not a partial
copy, because `lib-q-zkp` builds against the `libQ` Cargo workspace (edition 2024, Rust >= 1.96) and
does not compile in isolation.

- **Upstream:** https://github.com/Enkom-Tech/libQ (Apache-2.0)
- **Pinned commit:** `34cb3f04d871960162ee64a89a432f10de7ef826` (tag `v0.0.8`)
- **Path here:** `artifact/libQ`

```sh
# from the repository root
git submodule update --init
git -C artifact/libQ rev-parse HEAD     # must print the pinned commit above
```

Everything the paper relies on is in the `lib-q-zkp` crate:

| Paper part | Location under `artifact/libQ/lib-q-zkp/` |
|---|---|
| Shared in-circuit gadgets (§3-4) | `src/air/wide_sponge.rs`, `src/air/wide_merkle_path.rs`, `src/air/wide_hash.rs`; membership API `src/membership.rs`, `src/circuit.rs`, `src/api.rs` |
| Arm A AIR, GF(p²)/Mersenne-31, α=5 (§3-4, §5.1) | `src/air/unlinkable_membership.rs`, `src/air/poseidon_gadget.rs`, `src/stark.rs`, `src/merkle.rs` |
| Arm B AIR, BabyBear/Poseidon2, α=7 (§3-4, §5.2) | `src/air/unlinkable_membership_baby_bear.rs`, `src/air/poseidon2_gadget.rs`, `src/stark_baby_bear.rs` (also the measurement harnesses), `src/merkle_baby_bear.rs` |
| Construction / integration tests | `tests/air_integration.rs` |
| Structural / under-constraint / negative-proof audit (§4) | `tests/ip_soundness_tests.rs`, `tests/unlinkable_membership_tests.rs` |
| Zero-knowledge (§6, O4) | `tests/zero_knowledge_tests.rs` |
| Soundness parameters / 128-bit-PQ (§6, §6.5) | `tests/security_parameter_tests.rs` |
| O1 Arm A analysis | `docs/membership-arm-a-soundness-params.md`, `docs/membership-adr113-freeze-gate-review.md` |
| O1 Arm B analysis | `docs/membership-arm-b-soundness-params.md`, `docs/membership-arm-b-obligation-packet.md`, `docs/membership-arm-b-poseidon2-gadget-design.md` |
| Adversarial self-check | `docs/membership-arm-b-redteam.md` |
| Measured cost (§5.4) | `benches/zkp_benchmarks.rs`, harnesses `src/stark_baby_bear.rs::tests::measure_arm_{a,b}`, write-up `docs/membership-arm-b-measurement.md` |
| Wire format (informative) | `docs/membership-wire-v0-FROZEN.md` |

See [`../REPRODUCE.md`](../REPRODUCE.md) for the exact commands.

## Updating the pin

If you cut a release tag of `libQ` for archival, repin here and in the paper's Artifact Availability
section so all three agree:

```sh
git -C artifact/libQ checkout <tag-or-commit>
git add artifact/libQ
git commit -m "artifact: pin libQ to <tag-or-commit>"
```
