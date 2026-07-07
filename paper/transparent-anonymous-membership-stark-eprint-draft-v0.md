# Transparent, Post-Quantum Anonymous Set Membership from FRI-STARKs over BabyBear and Mersenne-31

**Enoch Kuskoff**
Enkom Tech · `en.cipher@enkom.tech`

*A construction-and-analysis note that solicits external review of its security arguments.*

> **Scope of this note.** A self-contained description of a transparent anonymous set-membership
> argument and its security analysis, presented as a generic primitive. The building blocks
> (FRI-STARKs, Poseidon, sponge hashing, nullifier-based membership) are standard; the contribution
> is the *concrete instantiation and its parameters* together with an explicit security analysis. We
> do **not** claim the construction is proven secure: two central questions, the GF(p²)-state
> Poseidon round counts (O1, specific to Arm A) and the formal zero-knowledge simulator (O4, shared by
> both arms), are stated as **open problems on which we solicit review** (Sections 6–7), not as
> established results (O2 and O3 reduce to the permutation's security, i.e. O1).

---

## Abstract

We describe and analyze a transparent, plausibly post-quantum argument of *anonymous set
membership with a nullifier*: a prover demonstrates, in zero knowledge, that it knows a secret
`t` whose leaf `L = H(t)` lies in a public Merkle accumulator with root `root`, and simultaneously
publishes a context-bound nullifier `N = H(domain ‖ t ‖ ctx)` that is unlinkable across contexts
but stable within one. The argument is a FRI-STARK over a small `31`-bit prime field, using a single
algebraic hash (a Poseidon-family permutation in a wide-sponge mode) for the leaf, every Merkle node,
and the nullifier. Transparency (no trusted setup) and a
hash-only soundness assumption make the construction conservative against quantum adversaries.

We give a complete security analysis along four axes: (O1) algebraic / Gröbner-basis security of
the permutation round counts; (O2) collision and second-preimage resistance of the truncated-output
sponge; (O3) domain separation between the leaf and nullifier pre-images; and (O4) the
zero-knowledge simulator for the hiding-PCS instantiation. We **implement, measure, and compare** two field instantiations of the hash. Arm A runs the
permutation *state* over the quadratic extension `GF(p²)` of Mersenne-31; Arm B runs over the base
field of BabyBear with the deployed Poseidon2. Both are implemented, and their proof-system soundness
is computed to `128`-bit post-quantum (Section 6.5); at equal security, **Arm B's proofs are
`≈ 14–18×` smaller and verify `≈ 16–17×` faster**, and we recommend it. We
explicitly solicit review of the two residuals our engineering arguments do not settle: the
extension-field round-count parameterization *specific to Arm A* (O1), and the zero-knowledge
simulator's masking-degree budget (O4, shared by both arms).

**Keywords.** anonymous set membership · nullifiers · zero-knowledge proofs · FRI-STARKs ·
transparent setup · post-quantum cryptography · Poseidon / Poseidon2 · algebraic hashing ·
BabyBear / Mersenne-31.

---

## 1. Introduction

Anonymous set membership with nullifiers underlies anonymous signaling, one-person-one-vote /
rate-limiting, private credentials, and privacy-preserving messaging (e.g. Semaphore-style
signaling [Sem], rate-limiting nullifiers [RLN], and privacy pools). The standard shape is: members
are accumulated in a Merkle tree over a commitment `H(t)` of a secret `t`; to act, a member proves
in zero knowledge that its leaf is in the tree and reveals a deterministic nullifier `N` derived
from `t` and a context, so that double-action *within* a context is detectable while actions
*across* contexts are unlinkable.

Most deployed instantiations use pairing- or discrete-log-based SNARKs (Groth16, PLONK) with a
trusted or universal setup, and rely on assumptions broken by a quantum adversary. We target a
**transparent** (setup-free) and **plausibly post-quantum** instantiation by realizing the relation
as an AIR proven with a **FRI-STARK** [BBHR18, BGKS20], whose soundness rests only on collision
resistance of a hash and the FRI low-degree test. The single algebraic hash is a Poseidon-family
permutation [GKRRS21, GKS23] in a wide-sponge mode, chosen for low AIR degree.

A second post-quantum route is *lattice-based* succinct ZK, e.g. LaBRADOR [LaBRADOR] and the recent
toolkit of Biasioli et al. [BBL+26] that adds zero-knowledge to it, which yields markedly smaller
proofs (under 100 KB) but rests on structured-lattice assumptions (Module-SIS / LWE). We deliberately
take the more conservative *hash-only* path (its sole assumption is collision resistance and it needs
no trusted setup), and target a purpose-built membership relation rather than a general prover
(Section 5).

**Contributions.**
1. A self-contained description of the membership AIR: trace layout, in-circuit sponge constraints,
   Merkle path threading, the nullifier sub-circuit, and the public-input binding (Sections 3–4).
2. Two concrete, **implemented and measured** field instantiations of the hash: a `GF(p²)`-*state*
   variant over Mersenne-31 (Arm A) and a base-field Poseidon2 variant over BabyBear (Arm B), with
   their digest widths, security margins, wire sizes, and a side-by-side cost comparison (Section 5).
3. A four-axis security analysis (O1–O4, Section 6) carried out against the published round-count
   and sponge-indifferentiability bounds, including an adversarial self-check against the recent
   algebraic-attack literature.
4. A precise statement of the two residual questions on which we seek external review (Section 7).

We make no claim that the underlying techniques are new. The value we hope to add is a *published,
reviewable* concrete parameter set and analysis for a transparent, hash-only anonymous-membership
argument over a small prime field.

---

## 2. Preliminaries

**Field.** Arm A uses `p = 2³¹ − 1` (Mersenne-31), a 31-bit prime; `GF(p²)` denotes the quadratic
extension realized as `Complex<GF(p)>` with `i² = −1` (valid since `−1` is a non-residue:
`p ≡ 3 (mod 4)`); a `GF(p²)` element packs two base limbs, `log₂|GF(p²)| ≈ 62`. Arm B (Section 5.2)
instead uses the **BabyBear** prime `q = 2³¹ − 2²⁷ + 1` (also `31`-bit, but two-adic of order `2²⁷`)
as its base field. Field-generic statements below are written over `F`.

**Algebraic permutation.** We use a Poseidon-family permutation `π` over `Fᵗ` (state width `t`)
with an `x^α` S-box: `α = 5` for Arm A (`gcd(5, p−1) = gcd(5, p²−1) = 1`, so `x⁵` permutes both
`GF(p)` and `GF(p²)`); `α = 7` for Arm B (since `5 ∣ q−1` makes `x⁵` non-bijective over BabyBear).
There are `R_F` full rounds and `R_P` partial rounds, ARC (add-round-constant), and an
MDS / Poseidon2 external+internal linear layer. Round constants are derived by an XOF / Grain-LFSR
from a fixed domain string.

**Sponge.** `H` is the sponge [BDPV07] over `π` with rate `r`, capacity `c` (`t = r + c`), `10*1`
padding, and a *truncated* output equal to the first `w_out` cells of the final state. We use `H`
for the leaf `L = H(t)`, every Merkle node `H(left ‖ right)`, and the nullifier
`N = H(domain ‖ t ‖ ctx)`.

**FRI-STARK / AIR.** The relation is expressed as an Algebraic Intermediate Representation (AIR):
an execution trace (a matrix over the field) and a set of polynomial constraints of bounded degree,
proven low-degree after the relation is reduced to a quotient via FRI [BBHR18]. We use a STARK whose
trace, constraints, and FRI all live over a common field `F` (Section 5 discusses `F = GF(p²)` for
Arm A vs. the two-adic base-field BabyBear configuration for Arm B; both run on a radix-2 FRI domain,
not a circle-STARK [HLP24]).

**Zero-knowledge.** Plain STARK traces are not zero-knowledge. We obtain ZK via a *hiding* polynomial
commitment: the trace is low-degree-extended at an increased blow-up with vanishing-polynomial
randomization, Merkle commitments are salted with fresh CSPRNG output, and FRI runs on the randomized
codeword [Hab22, BCRSVW19]. Only the public statement `(root, ctx, N)` is revealed.

---

## 3. The Membership Relation

Fix a domain constant `domain` (a baked circuit constant, *not* a witness or public input), derived
as the first `|domain|` cells of `H(S)` for a fixed statement string `S`. The argument proves, for
public `(root, ctx, N)`:

```
∃ (t, path) :
      MerkleVerify(root, L = H(t), path) = true
    ∧ N = H(domain ‖ t ‖ ctx)
reveal only (root, ctx, N);   L and t remain secret.
```

`root` is the verifier-supplied, trusted accumulator root; `ctx` is a public per-context label; `N`
is the nullifier. Membership soundness reduces to: a prover cannot make the AIR accept unless it
folds a genuine `H(t)` to the trusted `root` and emits the correctly-derived `N`. Anonymity reduces
to: the proof, `root`, and `N` reveal nothing about which leaf `L` was used (within the anonymity
set of the tree) and `N` is unlinkable across distinct `ctx`.

---

## 4. Construction (the AIR)

**Trace.** One row per Merkle level, plus row-0 carrying the leaf and nullifier sponge blocks. The
public values are the `w_out`-cell `root`, the `|ctx|`-cell `ctx`, and the `w_out`-cell `N`.

**In-circuit sponge.** Each hash invocation is unrolled into `⌊L/r⌋ + 1` permutation applications
(`L` = input length in cells). Every round intermediate is pinned by exactly one constraint:
ARC, the `x^α` S-box, and the linear layer in full rounds; in partial rounds the non-active lanes are
copy-constrained so they cannot be freely chosen. Capacity is threaded as the linear-layer
*expression* between permutations (no free capacity column), and the digest is the first `w_out`
cells of the genuine final-state expression, never a free read-back column. The absorb +`10*1`
padding schedule matches a value-level reference, checked across input lengths.

**Merkle threading.** Per level: a boolean `dir` selects the node input order
(`(running, sibling)` vs. `(sibling, running)`); `running` is updated to the node hash; a transition
constraint forces `next.running = parent`; the last row binds `parent = root`. Trees of varying
depth are handled by deterministically extending `root` with zero-sibling levels (padding-blind in
the AIR; soundness rests on the verifier feeding its *own* trusted `root`).

**Nullifier.** The `|domain|`-cell `domain` prefix is injected as constant expressions (no committed
domain column). The pre-image is exactly `domain ‖ t ‖ ctx`. The single committed `t` slice feeds *both*
the leaf sponge and the nullifier pre-image (so leaf and nullifier are structurally same-`t`).
Row-0 gated constraints bind `running = L`, `ctx = public ctx`, and `null_out = public N`.

**Degree.** Max constraint degree is `α` (the ungated `x^α` S-box: `5` for Arm A, `7` for Arm B);
selectors gate only degree-1 bindings. The quotient-chunk count is derived from the constraint AST by both prover and verifier,
so any degree overflow fails at prove time.

A structural audit of this AIR (sponge under-constraint, Merkle threading, leaf/same-`t`, nullifier
integrity, padding rows, padding-root, public binding, degree/FRI config) found no relation a
malicious prover can exploit to accept a proof that violates the decoded statement, *modulo* the
cryptographic assumptions O1–O4 below.

---

## 5. Field Instantiation

The single design lever with security and cost consequences is the **field over which the hash
permutation state runs**. We describe, implement, and measure both arms. **Both are realized, and
their proof-system soundness computes to `128`-bit post-quantum (Section 6.5); Arm B is the
instantiation we recommend.** Arm
A runs the permutation state over the quadratic extension `GF(p²)` of Mersenne-31; Arm B runs over
the base field of BabyBear with the deployed Poseidon2. Measured at equal security, Arm B's proofs
are `≈ 14–18×` smaller and verify `≈ 16–17×` faster (Section 5.4), and its round-count obligation (O1) is a
near-citation of a standard parameter set rather than the novel extension-field analysis Arm A
requires. All other aspects of the construction (Sections 3–4) are identical between the two.

### 5.1 Arm A: `GF(p²)`-state (the analyzed instantiation)

State width `t = 7`, rate `r = 2`, capacity `c = 5`, `R_F = 8`, `R_P = 60`, `α = 5`, over `GF(p²)`.
Each state cell is a `GF(p²)` element (`≈ 62` bits). Digest `w_out = 5` cells `= 5 × 8 = 40` bytes
`= 5 × 62 ≈ 310` bits. The STARK trace, constraints, and FRI all run over `GF(p²)`.

- **Pro:** the wide `≈ 62`-bit cells give a `5`-cell, `310`-bit digest and `155`-bit capacity
  collision resistance with only `c = 5`.
- **Con:** running the *whole* trace and FRI over `GF(p²)` pays a `≈ 2×` field tax on all prover
  arithmetic and committed data; and the published round-count formulas (Section 6, O1) target the
  *base* prime field, so the extension-field state requires the dedicated analysis of O1.

The FRI challenges are drawn from a **degree-3 extension `GF(p⁶) ≈ 186` bits**: the `≈ 62`-bit value
field is too small to serve as its own challenge field at `128`-bit soundness, so the membership
prover/verifier lift the challenge/OOD sampling into `GF(p⁶)` (Section 6.5).

Public statement: `root(40) ‖ ctx(16) ‖ N(40) = 96` bytes; per-cell encoding `4`-byte real `‖`
`4`-byte imaginary, canonical.

### 5.2 Arm B: base-field BabyBear / Poseidon2 (the realized, recommended instantiation)

State width `t = 16`, `R_F = 8` (`4 + 4`), `R_P = 13`, `α = 7`, over the **BabyBear** prime field
`q = 2³¹ − 2²⁷ + 1` (`log₂ q ≈ 30.9`), using the *deployed* Poseidon2 parameters [GKS23, Plonky3]:
the external block-circulant `4×4` MDS layer, the optimized internal diagonal, and Grain-LFSR round
constants from the reference generator, i.e. the width-16 instance shipped by Plonky3/SP1. BabyBear, not
Mersenne-31, is the base field for a deliberate reason: M31's base field has 2-adicity `1` (no
radix-2 FFT subgroup), so a base-`M31` STARK would require *circle* STARKs [HLP24]; BabyBear's
2-adicity `27` gives a native two-adic FFT domain, so Arm B runs on the **same `TwoAdicFriPcs`**
machinery as Arm A; only the field and permutation change, not the proof system. BabyBear's S-box is
`x⁷` (`α = 7`, since `5 ∣ q−1` makes `x⁵` non-bijective).

To preserve a `≥ 256`-bit digest with `≈ 31`-bit cells, the capacity and output widen to
`⌈256/30.9⌉ = 9` cells: sponge `t = 16, r = 7, c = 9, w_out = 9` (`≈ 278`-bit capacity `→ ≈ 139`-bit
collision; `9 × 4 = 36`-byte digest). FRI challenges are drawn from a degree-5 extension
`GF(q⁵) ≈ 155` bits, sized for `128`-bit soundness (Section 6.5).

- **Pro:** O1 reduces from a novel extension-field analysis to a near-*citation* of the standard,
  widely-deployed BabyBear Poseidon2 parameter set (Plonky3/SP1); and the base-field trace (`4`-byte
  cells) avoids the `GF(p²)` field tax across the whole proof. Measured, the effect is decisive
  (Section 5.4).
- **Realization:** Arm B is fully implemented and tested **for functional correctness**: the field,
  the deployed Poseidon2 (KAT against the published reference vector), the in-circuit gadget, the wide
  sponge / Merkle, the membership AIR, and a transparent **and** zero-knowledge prover/verifier, with
  an exhaustive per-column under-constraint audit and a negative-proof matrix over all sub-AIRs. This
  is functional evidence, **not** a soundness proof: like Arm A, Arm B remains open on O1/O4
  (Sections 6–7). Public statement: `root(36) ‖ ctx(16) ‖ N(36) = 88` bytes, per-cell `4`-byte
  canonical little-endian.

### 5.3 What the field choice does and does not change

The field choice governs O1 (round-count security) and, through it, O2/O3 (collision and
domain-separation, which assume a secure permutation). It does **not** affect O4 (the
zero-knowledge simulator), which is a property of the hiding PCS and the masking-degree budget, not
of the hash field. A reviewer's verdict on O4 transfers unchanged between the two arms.

### 5.4 Measured cost (both arms, equal `128`-bit-PQ security)

Both arms are implemented and benchmarked at their `128`-bit-PQ configurations (Arm A: `GF(p⁶)`
challenge, `log_blowup 3`; Arm B: `GF(q⁵)` challenge, `log_blowup 4`; both bind on a SHAKE256 Merkle
commitment at `128` bits; Section 6.5). Single-thread, median of 5, membership depth 32:

| | Arm A (`GF(p²)` / Poseidon256) | Arm B (BabyBear / Poseidon2) | Arm B advantage |
|--|---:|---:|---:|
| Trace row width | `17 152` | `1 661` | `≈ 10×` narrower |
| Bytes per trace row | `137 216` | `6 644` | `≈ 21×` smaller |
| Proof size, transparent | `≈ 16.4` MB | `≈ 1.04` MB | **`≈ 16.6×` smaller** |
| Proof size, zero-knowledge | `≈ 16.7` MB | `≈ 1.21` MB | **`≈ 14.4×` smaller** |
| Verify time | `≈ 510` ms | `≈ 30` ms | **`≈ 17×` faster** |

The gap is **at equal security** (both reach the same `128`-bit hash floor), not a size-for-security
trade. It tracks bytes-per-trace-row: FRI opens `#queries × trace_width` field elements, and Arm A's
Poseidon256 (`t = 7`, `68` rounds, `8`-byte `GF(p²)` cells) yields a far wider, heavier row than Arm
B's Poseidon2 (`t = 16`, `21` rounds, `4`-byte cells). This field/permutation effect, not the FRI
blowup, dominates, so it holds across depths and in both transparent and zero-knowledge modes.

---

## 6. Security Analysis (O1–O4)

The structural audit shows the constraints faithfully encode the intended hash and Merkle relations.
The following are the cryptographic obligations that an automated/structural argument cannot
discharge. We give engineering derivations against the published formulas; we do **not** claim these
are a substitute for independent expert review (Section 7).

### O1: Round-count / algebraic-degree security

**Instance (Arm A).** `α = 5`, `t = 7`, `R_F = 8`, `R_P = 60` (68 rounds) over `GF(p²)`,
`log₂|F| ≈ 62`. Target `M = 128`-bit.

We evaluate the published POSEIDON round-count bounds [GKRRS21, §5.5; ABM23]: statistical,
interpolation, and the Gröbner-basis family, reproduced from the canonical generators. With
`n = log₂ p` the field-size term, `log₅2 ≈ 0.43068`:

- **Statistical:** `R_F ≥ 6` if `M ≤ ⌊n − (α−1)/2⌋(t+1)`, else `R_F ≥ 10`.
- **Interpolation:** `R_F + R_P ≥ 1 + ⌈log₅2 · min(M,n)⌉ + ⌈log₅ t⌉`.
- **Gröbner:** several bounds, incl. `(t−1)(R_F+R_P) ≥ (t−2) + M/(2 log₂ α)` and the
  Macaulay-style `cost_gb ≥ M`.
- **Margin:** `+2` full rounds and `+7.5%` partial rounds over the minimum.

| Regime | Binding bound (interpolation) | Margined optimal `(R_F, R_P)` | Deployed `8 + 60` |
|---|---|---|---|
| `n = 62` (the realistic `GF(p²)` reading) | `1 + ⌈0.43068·62⌉ + 2 = 30` | `(8, 26)`, total 34 | **≈ 2× total / 2.3× R_P** |
| `n = 31` (pessimistic subfield substitution) | `1 + ⌈0.43068·31⌉ + 2 = 17` | `(8, 14)`, total 22 | **≈ 4.3× R_P** |

`cost_gb` for `(8, 60)` evaluates to `≈ 349` bits `≫ 128`. So `8 + 60` clears every published bound
under both the realistic and worst-case-subfield substitutions.

**Extension-field subtlety (the crux for review).** `GF(p²)`'s tower structure could *reduce*
security only via a **subfield descent**: if `GF(p)⁷` were invariant under the round function, an
attacker could work in the 31-bit subfield (`min(M,n) → 31`) and unlock invariant-subspace /
subspace-trail Gröbner attacks [Bariant+22, GKR25]. The defense is **generic round
constants**: drawing both the real and imaginary limb of every constant independently from the XOF
gives each constant a pseudorandom nonzero imaginary part (`Pr[imag = 0] ≈ 2⁻³¹` per constant), so a
single off-subfield constant per round maps `GF(p)⁷` off itself and breaks subfield invariance.
*Caveat for the reviewer:* if the linear (MDS) layer is built from base-field entries, the linear
layer alone preserves `GF(p)⁷`; the subfield defense then rests **entirely** on the constants'
genericity. A future change that de-randomized the constants' imaginary parts would re-expose the
subfield.

**Adversarial self-check.** The 2024–2026 algebraic-attack wave (the FreeLunch / CheapLunch Gröbner
attacks [FreeLunch, CheapLunch] and subspace-trail Gröbner cryptanalysis of Poseidon [GKR25])
pressures `R_P` by linearizing partial rounds; `R_P = 60` is `2.3–4.3×` the requirement, and the
instances those attacks render borderline run `R_P` at `≈ 1×`. The off-envelope concern reduces to
the constant-genericity check. Notably, [GKR25] finds that the *original* Poseidon round-count model
can itself mis-estimate the rounds required for some instantiations (under- or over-counting); this
makes the large `R_P = 60` margin reassuring but is a further reason expert review, not formula
evaluation alone, is warranted. The case does not survive automated scrutiny, but the residual
against *future* cryptanalysis of a `GF(p²)`-*state* permutation (an unusual deployment choice) is
real, and is why we seek review.

**Arm B contrast.** Arm B's permutation is the deployed BabyBear Poseidon2 [GKS23, Plonky3]: `α = 7`,
`t = 16`, `R_F = 8`, `R_P = 13` over the base prime field (`log₂ q ≈ 30.9`), the **standard,
widely-deployed** instantiation (Plonky3/SP1) the round-count formulas target directly. O1 becomes
confirmation that these published parameters are used unchanged (a base-field citation with no
tower / subfield-invariance / off-envelope-state concern) rather than the novel extension-field
analysis Arm A requires.

### O2: Collision / second-preimage of the truncated sponge

For a sponge on a random permutation, collision and (second-)preimage resistance are
`min(2^{c·log₂|F|/2}, 2^{w_out·log₂|F|/2})` up to the capacity [BDPV08].

- **Arm A:** capacity `5 · 62 = 310` bits `→ 2¹⁵⁵`; output `5 · 62 = 310` bits `→ 2¹⁵⁵` and
  `≥ 256`-bit digest. Required capacity for `M = 128` is `c ≥ 2M/log₂|F| = 256/62 ≈ 4.13`; `c = 5`
  clears it. Truncation to `w_out = 5 (≥ 4.13)` preserves `≥ 128`-bit output collision resistance;
  *internal* collisions (which enable Merkle-node equivocation) are governed by the capacity, not
  the output width, so truncation does not weaken node-collision resistance. Sponges with nonzero
  capacity are not length-extendable.
- **Arm B:** capacity `9 · 30.9 ≈ 278` bits `→ ≈ 2¹³⁹`; `9`-cell `≈ 278`-bit digest `≥ 256` bits
  (BabyBear `≈ 31`-bit cells; `c = 9 ≥ 2M/log₂q ≈ 8.3` clears the `128`-bit floor).

O2 holds *given* O1 (the permutation is a secure PRP at the `128`-bit level).

### O3: Domain separation (no leaf↔nullifier cross-collision)

The leaf preimage is the secret `t`; the nullifier preimage is the strictly longer
`domain ‖ t ‖ ctx`; both use the same sponge with `10*1` padding. (i) *Cross-protocol:* a distinct
`domain` constant forces a distinct absorption from round 1, giving disjoint nullifier images
(standard prefix domain separation). (ii) *No leaf↔nullifier impersonation:* the two preimages differ
in length (so they absorb in a different number of permutations), and the nullifier carries the
`domain` prefix the leaf lacks; a collision between them is therefore a generic cross-length collision
(O2), not a structural ambiguity, because `10*1` padding is injective on field-sequence inputs. O3
adds only the discipline that the domain string is globally unique to this statement.

### O4: Zero-knowledge simulator (field-independent)

**Implemented.** A hiding PCS (salted hiding-Merkle MMCS + FRI on a vanishing-poly-randomized
codeword at `log_blowup + 1`) keeps the witness (`t`, `L`, siblings, direction bits, all sponge
intermediates) in the blinded trace; only `(root, ctx, N)` is public. Two blinding-randomness leaks
that we found and fixed: (L1) the salts/blinding polynomials must come from a CSPRNG, not a linear
PRNG (a salted-but-linear generator is de-blindable when salts appear in the proof); (L2) the seeds
must be fresh, independent, `≥ 256`-bit per proof, drawn from an OS CSPRNG, not fixed/guessable
constants.

**The residual we seek review on.** A formal simulator `S` that, given only `(root, ctx, N)`,
outputs proofs computationally indistinguishable from honest ones. The structure: `S` commits to a
random masking polynomial of the same degree budget and answers FRI/OOD queries via the standard
ZK-STARK simulation [BCRSVW19] + hiding-PCS zero-knowledge [Hab22]; indistinguishability reduces to
(i) hiding of the salted Merkle commitments and (ii) the masking degree **strictly exceeding** the
number of query + OOD openings, so every revealed evaluation is uniform and independent of the
witness. The **quantitative residual**: with the degree-`α` S-box forcing `log_blowup ≥ 3` and a
concrete `#queries + #OOD`, the masking degree under the hiding PCS must be confirmed `≥ #openings +
1` for the production parameters, and the truncated-output sponge openings (`w_out` of `t` cells)
must leak nothing beyond the public digest under that budget. O4 is field-independent; it transfers
unchanged between Arm A and Arm B.

### 6.5 Proof-system (PCS / FRI) soundness: the challenge field

O1–O4 concern the *hash*; the proof system has its own soundness, bounded by the FRI/DEEP challenge
field and the query phase and binding on the Merkle commitment. The field-dependent terms
(out-of-domain / DEEP / proximity-gap) are **capped by the size of the challenge field**, regardless
of query count, a subtlety that cost us a real error: Arm A originally drew its challenges from its
own `≈ 62`-bit value field `GF(p²)`, which caps DEEP soundness near `62` bits, and a query-only
estimate masked it. The fix is a larger challenge extension. Both arms now compute to `128`-bit
post-quantum soundness, **binding on a `256`-bit SHAKE256 Merkle commitment** (`128`-bit collision,
NIST Category 2):

- **Arm A:** challenge field `GF(p⁶)` (degree-3 over `GF(p²)`, `≈ 186` bits), `log_blowup 3`, `96`
  queries, `20` PoW bits → DEEP / Schwartz–Zippel `≈ 176` bits; binding term `128` (SHAKE256).
- **Arm B:** challenge field `GF(q⁵)` (degree-5 over BabyBear, `≈ 155` bits), `log_blowup 4`, `96`
  queries, `20` PoW bits → DEEP / Schwartz–Zippel `≈ 147` bits; binding term `128` (SHAKE256).

The post-quantum model is the deployed QROM one: Fiat–Shamir preserves a round-by-round-sound IOP up
to small factors, Grover halves only the grinding proof-of-work, and the SHAKE256 binding is the
`128`-bit term. This is a parameter characterization of the PCS layer; it assumes the AIR is sound
and complete (the structural audit and per-column mutation tests are evidence, not proof) and that
O1 holds.

---

## 7. Scope and the questions we seek review on

We do **not** claim O1–O4 are settled. The two residuals where independent expert review is
decisive:

1. **(O1) The `GF(p²)`-*state* parameterization (Arm A).** Running the *entire permutation state*
   over `GF(p²)` (rather than the base field, with the extension reserved for FRI challenges) is an
   unusual deployment choice. We have shown `8 + 60` clears the published bounds by `≈ 2×` and that
   generic round constants close the subfield-descent path, but we seek confirmation of: (a) the
   constant-genericity argument as the intended subfield defense; (b) the absence of a residual
   invariant subspace under the base-field MDS + generic-constant composition; (c) comfort with the
   `GF(p²)`-state convention against current and foreseeable algebraic cryptanalysis. *If a reviewer
   is uncomfortable, **Arm B, the recommended, implemented base-field instantiation, avoids this
   obligation entirely**, reducing O1 to conformance with published BabyBear Poseidon2 parameters.*
2. **(O4) The simulator's masking-degree budget.** We seek a formal simulator write-up and
   confirmation that the concrete masking degree `≥ #queries + #OOD + 1` for the production
   parameters, and that the truncated-output sponge openings leak nothing under that budget.

On **Arm A vs. Arm B**: we recommend Arm B on the measured merits (at equal `128`-bit security its
proofs are `≈ 14–18×` smaller and verify `≈ 16–17×` faster, Section 5.4) *and* on the cleaner O1 (a
base-field parameter citation, not an extension-field analysis). Arm A is the original `GF(p²)`
instantiation; we retain its full analysis because the `GF(p²)`-state construction is of independent
interest, but the off-envelope O1 above is why we do not lead with it.

A reviewer wishing to reproduce the O1 evaluation needs only the parameters in Section 5 and the
public generators cited below; no proprietary material is involved.

---

## 8. Related Work

- **Algebraic hashes.** POSEIDON [GKRRS21] and POSEIDON2 [GKS23] establish the round-count formulas
  and the base-field parameterizations we cite; the HADES design strategy and its algebraic
  cryptanalysis [ABM23], with the recent attack literature [Bariant+22; FreeLunch; CheapLunch;
  GKR25], inform the O1 self-check.
- **Sponge security.** The indifferentiability and truncated-output bounds are from
  Bertoni–Daemen–Peeters–Van Assche [BDPV07, BDPV08].
- **Transparent STARKs.** FRI and STARKs [BBHR18, BGKS20]; circle STARKs over Mersenne-31 [HLP24];
  zero-knowledge STARKs / hiding PCS [BCRSVW19, Hab22]; the Plonky3 toolkit provides the BabyBear
  Poseidon2 reference parameters (Arm B) and the two-adic FRI machinery both arms use.
- **Post-quantum proof systems (the other family).** The principal alternative post-quantum ZK route
  is *lattice-based*: LaBRADOR [LaBRADOR] and the succinct-ZK toolkit of Biasioli et al. [BBL+26]
  (building on it) give sub-100 KB proofs for general statements (the smallest among post-quantum
  schemes) at the cost of structured-lattice assumptions. We instead rest only on hash collision
  resistance (transparent, no algebraic structure), trading proof size for a more conservative
  assumption and a purpose-built membership relation.
- **Anonymous membership / nullifiers.** Semaphore-style signaling [Sem], rate-limiting nullifiers
  [RLN], the PLUME deterministic-nullifier scheme [PLUME], and privacy-pool constructions establish
  the leaf/nullifier pattern; our contribution is a
  transparent, hash-only (post-quantum-oriented) instantiation over a small prime field, with the
  accompanying parameter analysis.

## Artifact Availability

All code, parameters, in-circuit audits, and the benchmarking harness behind the claims in this note
are open source, so that the construction (Sections 3–4), the parameter sets and security analysis
(Sections 5–6), and the measured comparison (Section 5.4) can be independently rebuilt and verified.

- **Implementation.** *Both arms* are implemented in the `lib-q-zkp` crate of the `libQ` library:
  <https://github.com/Enkom-Tech/libQ> (Apache-2.0), pinned at commit `34cb3f0` (tag `v0.0.8`). Shared in-circuit
  gadgets: `src/air/wide_sponge.rs`, `wide_merkle_path.rs`, `wide_hash.rs`; membership API:
  `src/membership.rs` / `src/circuit.rs` / `src/api.rs`.
  **Arm A** (GF(p²) / Mersenne-31): membership AIR `src/air/unlinkable_membership.rs`, gadget
  `src/air/poseidon_gadget.rs` (α=5), STARK config `src/stark.rs`, Merkle `src/merkle.rs`.
  **Arm B** (BabyBear / Poseidon2): membership AIR `src/air/unlinkable_membership_baby_bear.rs`,
  gadget `src/air/poseidon2_gadget.rs` (α=7), STARK config `src/stark_baby_bear.rs`, Merkle
  `src/merkle_baby_bear.rs`. Both expose transparent and zero-knowledge prover/verifier paths.
- **Reproduction package.** A companion repository bundles this paper's source together with a pinned
  snapshot (git submodule) of `libQ` and a `REPRODUCE.md` that maps each claim to the file, test, or
  benchmark that backs it: <https://github.com/En-Cipher/transparent-pq-anonymous-membership>.
- **Security analysis (O1–O4).** The round-count / soundness derivations are in
  `docs/membership-arm-a-soundness-params.md`, `membership-arm-b-soundness-params.md`,
  `membership-arm-b-obligation-packet.md`, `membership-adr113-freeze-gate-review.md`, and the
  adversarial self-check in `membership-arm-b-redteam.md`. The structural / under-constraint audit is
  exercised by `tests/air_integration.rs`, `tests/ip_soundness_tests.rs`,
  `tests/unlinkable_membership_tests.rs`, `tests/zero_knowledge_tests.rs`, and
  `tests/security_parameter_tests.rs`.
- **Measured cost (Section 5.4).** Produced by `benches/zkp_benchmarks.rs` (harness `measure_arm_a` /
  Arm B), documented in `docs/membership-arm-b-measurement.md`. Environment: AMD Ryzen 9 5900X
  (12C/24T), Windows 10 IoT x86_64, Rust 1.96 (edition 2024), `cargo test --release`, single-threaded
  (the `parallel`/rayon feature off), prove and verify reported as the median of 5, proof size via
  `postcard::to_allocvec(proof).len()`. Absolute timings are hardware-dependent; the cross-arm
  *ratios* are the reproducible result.

## Acknowledgements

**Use of generative AI tools.** The construction, the parameter choices, the security analysis, and
the open questions raised for review are the author's own work. Generative AI software (Anthropic
Claude, via Claude Code) was used as a drafting and editing aid for the exposition and to cross-check
the write-up against the cited literature; all technical content was directed, checked, and is
vouched for by the author. The author is solely responsible for the veracity and correctness of all
claims; generative AI is not, and cannot be, an author.

## References

- [GKRRS21] L. Grassi, D. Khovratovich, C. Rechberger, A. Roy, M. Schofnegger. *Poseidon: A New Hash
  Function for Zero-Knowledge Proof Systems.* USENIX Security 2021. IACR ePrint 2019/458.
- [GKS23] L. Grassi, D. Khovratovich, M. Schofnegger. *Poseidon2: A Faster Version of the Poseidon
  Hash Function.* AFRICACRYPT 2023. IACR ePrint 2023/323.
- [ABM23] T. Ashur, T. Buschman, M. Mahzoun. *Algebraic Cryptanalysis of the HADES Design Strategy:
  Application to Poseidon and Poseidon2.* ACISP 2024. IACR ePrint 2023/537.
- [BDPV07] G. Bertoni, J. Daemen, M. Peeters, G. Van Assche. *Sponge Functions.* ECRYPT Hash
  Workshop 2007.
- [BDPV08] G. Bertoni, J. Daemen, M. Peeters, G. Van Assche. *On the Indifferentiability of the
  Sponge Construction.* EUROCRYPT 2008, LNCS 4965, pp. 181–197.
- [BBHR18] E. Ben-Sasson, I. Bentov, Y. Horesh, M. Riabzev. *Scalable, Transparent, and
  Post-Quantum Secure Computational Integrity.* IACR ePrint 2018/046.
- [BGKS20] E. Ben-Sasson, L. Goldberg, S. Kopparty, S. Saraf. *DEEP-FRI: Sampling Outside the Box
  Improves Soundness.* ITCS 2020. IACR ePrint 2019/336.
- [HLP24] U. Haböck, D. Levit, S. Papini. *Circle STARKs.* IACR ePrint 2024/278.
- [BCRSVW19] E. Ben-Sasson, A. Chiesa, M. Riabzev, N. Spooner, M. Virza, N. Ward. *Aurora:
  Transparent Succinct Arguments for R1CS.* EUROCRYPT 2019. IACR ePrint 2018/828.
- [Hab22] U. Haböck. *A Summary on the FRI Low Degree Test.* IACR ePrint 2022/1216.
- [Bariant+22] A. Bariant, C. Bouvier, G. Leurent, L. Perrin. *Algebraic Attacks against Some
  Arithmetization-Oriented Primitives.* IACR Trans. Symmetric Cryptol. 2022(3), pp. 73–101.
- [FreeLunch] A. Bariant, A. Bœuf, A. Lemoine, I. Manterola Ayala, M. Øygarden, L. Perrin, H. Raddum.
  *The Algebraic FreeLunch: Efficient Gröbner Basis Attacks Against Arithmetization-Oriented
  Primitives.* CRYPTO 2024. IACR ePrint 2024/347.
- [CheapLunch] *The Algebraic CheapLunch: Extending FreeLunch Attacks on Arithmetization-Oriented
  Primitives Beyond CICO-1.* IACR ePrint 2025/2040.
- [GKR25] L. Grassi, K. Koschatko, C. Rechberger. *Poseidon and Neptune: Gröbner Basis Cryptanalysis
  Exploiting Subspace Trails.* IACR Trans. Symmetric Cryptol. 2025. IACR ePrint 2025/954.
- [Plonky3] The Plonky3 Authors. *Plonky3: A toolkit for polynomial IOPs / STARKs.* Software,
  `github.com/Plonky3/Plonky3` (source of the BabyBear Poseidon2 reference parameters).
- [LaBRADOR] W. Beullens, G. Seiler. *LaBRADOR: Compact Proofs for R1CS from Module-SIS.* CRYPTO 2023.
  IACR ePrint 2022/1341.
- [BBL+26] B. Biasioli, M. Bolboceanu, V. Lyubashevsky, A. Merino-Gallardo, M. Osadnik, G. Seiler,
  P. Steuer. *A Toolkit for Succinct Lattice-Based Zero-Knowledge Proofs.* IACR ePrint 2026/1289.
- [Sem] Semaphore Protocol (Privacy & Scaling Explorations). *A zero-knowledge protocol for anonymous
  signaling / group membership.* Documentation: `https://docs.semaphore.pse.dev`; source:
  `github.com/semaphore-protocol/semaphore`.
- [RLN] Rate-Limiting Nullifier (Privacy & Scaling Explorations). *A Merkle-membership + nullifier
  spam-prevention gadget built on Semaphore (Shamir-secret-sharing key recovery on a rate-limit
  breach).* Documentation: `https://rate-limiting-nullifier.github.io/rln-docs/`; source:
  `github.com/Rate-Limiting-Nullifier`.
- [PLUME] A. Gupta, K. Gurkan. *PLUME: An ECDSA Nullifier Scheme for Unique Pseudonymity within
  Zero-Knowledge Proofs.* IACR ePrint 2022/1255.
