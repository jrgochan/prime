"""
Project HYPERZETA: Lemma Ladder
================================
Instead of asking the LLM to prove RiemannHypothesis in one shot,
we decompose into a sequence of increasingly difficult sub-proofs.

Each proved lemma becomes a tool (injected into the prompt) for harder ones.
The first rungs are near-trivial API lookups — the point is to teach the LLM
how to use Mathlib. Later rungs require genuine proof construction.

The final rung IS RiemannHypothesis.
"""

# Each rung: name, title, difficulty, max_attempts, lean_statement, hints, relevant_tools
LEMMA_LADDER = [
    # ═══════════════════════════════════════════════════════
    # RUNG 1: ζ(0) = -1/2 (trivial — one Mathlib lemma)
    # ═══════════════════════════════════════════════════════
    {
        "name": "zeta_at_zero",
        "title": "ζ(0) = -1/2",
        "difficulty": "trivial",
        "max_attempts": 50,
        "lean_statement": (
            "theorem zeta_at_zero : riemannZeta 0 = -1/2 :=\n"
            "  sorry"
        ),
        "hints": (
            "This is a DIRECT application of a single Mathlib lemma. "
            "The lemma `riemannZeta_zero` states exactly this. "
            "The proof is likely one line: `exact riemannZeta_zero` or use `simp [riemannZeta_zero]`."
        ),
        "relevant_tools": ["riemannZeta_zero", "exact", "simp", "norm_num"],
    },

    # ═══════════════════════════════════════════════════════
    # RUNG 2: Trivial zeros ζ(-2(n+1)) = 0
    # ═══════════════════════════════════════════════════════
    {
        "name": "zeta_trivial_zeros",
        "title": "Trivial zeros: ζ(-2(n+1)) = 0",
        "difficulty": "trivial",
        "max_attempts": 50,
        "lean_statement": (
            "theorem zeta_trivial_zeros (n : ℕ) : riemannZeta (-2 * (↑n + 1)) = 0 :=\n"
            "  sorry"
        ),
        "hints": (
            "This is a DIRECT application of `riemannZeta_neg_two_mul_nat_add_one`. "
            "The proof is one line: `exact riemannZeta_neg_two_mul_nat_add_one n`."
        ),
        "relevant_tools": ["riemannZeta_neg_two_mul_nat_add_one", "exact"],
    },

    # ═══════════════════════════════════════════════════════
    # RUNG 3: Completed zeta symmetry Λ(1-s) = Λ(s)
    # ═══════════════════════════════════════════════════════
    {
        "name": "completed_zeta_symmetry",
        "title": "Functional equation: Λ(1-s) = Λ(s)",
        "difficulty": "easy",
        "max_attempts": 75,
        "lean_statement": (
            "theorem completed_zeta_symmetry (s : ℂ) :\n"
            "    completedRiemannZeta (1 - s) = completedRiemannZeta s :=\n"
            "  sorry"
        ),
        "hints": (
            "This is the Riemann functional equation for the completed zeta function. "
            "Mathlib has `completedRiemannZeta_one_sub` which states exactly this. "
            "Try: `exact completedRiemannZeta_one_sub s`."
        ),
        "relevant_tools": ["completedRiemannZeta_one_sub", "exact"],
    },

    # ═══════════════════════════════════════════════════════
    # RUNG 4: Entire completed zeta symmetry Λ₀(1-s) = Λ₀(s)
    # ═══════════════════════════════════════════════════════
    {
        "name": "completed_zeta0_symmetry",
        "title": "Entire functional equation: Λ₀(1-s) = Λ₀(s)",
        "difficulty": "easy",
        "max_attempts": 75,
        "lean_statement": (
            "theorem completed_zeta0_symmetry (s : ℂ) :\n"
            "    completedRiemannZeta₀ (1 - s) = completedRiemannZeta₀ s :=\n"
            "  sorry"
        ),
        "hints": (
            "The entire completed zeta (poles removed) also satisfies the functional equation. "
            "Mathlib has `completedRiemannZeta₀_one_sub`. "
            "Try: `exact completedRiemannZeta₀_one_sub s`."
        ),
        "relevant_tools": ["completedRiemannZeta₀_one_sub", "exact"],
    },

    # ═══════════════════════════════════════════════════════
    # RUNG 5: ζ is differentiable away from s=1
    # ═══════════════════════════════════════════════════════
    {
        "name": "zeta_differentiable",
        "title": "ζ(s) is differentiable for s ≠ 1",
        "difficulty": "easy-medium",
        "max_attempts": 100,
        "lean_statement": (
            "theorem zeta_differentiable (s : ℂ) (hs : s ≠ 1) :\n"
            "    DifferentiableAt ℂ riemannZeta s :=\n"
            "  sorry"
        ),
        "hints": (
            "Mathlib has `differentiableAt_riemannZeta` which requires `s ≠ 1`. "
            "Try: `exact differentiableAt_riemannZeta hs`. "
            "Note the hypothesis `hs : s ≠ 1` matches exactly what the lemma needs."
        ),
        "relevant_tools": ["differentiableAt_riemannZeta", "exact"],
    },

    # ═══════════════════════════════════════════════════════
    # RUNG 6: Λ₀ is entire (differentiable everywhere)
    # ═══════════════════════════════════════════════════════
    {
        "name": "completed_zeta0_entire",
        "title": "Λ₀(s) is entire (differentiable everywhere)",
        "difficulty": "easy-medium",
        "max_attempts": 100,
        "lean_statement": (
            "theorem completed_zeta0_entire :\n"
            "    Differentiable ℂ completedRiemannZeta₀ :=\n"
            "  sorry"
        ),
        "hints": (
            "Mathlib proves that the entire completed zeta function is differentiable everywhere. "
            "Look for `differentiable_completedZeta₀` or similar. "
            "Try `exact differentiable_completedZeta₀` or `exact Differentiable.comp ...`."
        ),
        "relevant_tools": ["differentiable_completedZeta₀", "exact"],
    },

    # ═══════════════════════════════════════════════════════
    # RUNG 7: Zero symmetry via functional equation
    # ═══════════════════════════════════════════════════════
    {
        "name": "zero_symmetry",
        "title": "Non-trivial zeros are symmetric: ζ(s)=0 → ζ(1-s)=0",
        "difficulty": "medium",
        "max_attempts": 200,
        "lean_statement": (
            "theorem zero_symmetry (s : ℂ)\n"
            "    (h_zero : riemannZeta s = 0)\n"
            "    (h_not_neg_nat : ∀ n : ℕ, s ≠ -↑n)\n"
            "    (h_ne_one : s ≠ 1) :\n"
            "    riemannZeta (1 - s) = 0 :=\n"
            "  sorry"
        ),
        "hints": (
            "EXACT PROOF STRATEGY (follow precisely):\n"
            "The Mathlib4 theorem `riemannZeta_one_sub` has signature:\n"
            "  riemannZeta_one_sub (hs : ∀ n : ℕ, s ≠ -↑n) (hs' : s ≠ 1) :\n"
            "    riemannZeta (1 - s) = 2 * (2 * ↑Real.pi) ^ (-s) * Complex.Gamma s\n"
            "      * Complex.cos (↑Real.pi * s / 2) * riemannZeta s\n"
            "Step 1: Rewrite the goal using `riemannZeta_one_sub h_not_neg_nat h_ne_one`.\n"
            "This transforms the goal to: `2 * ... * riemannZeta s = 0`.\n"
            "Step 2: Since riemannZeta s = 0 (by h_zero), the whole product is zero.\n"
            "Use `rw [h_zero, mul_zero]` or `simp [h_zero]`.\n"
            "COMPLETE PROOF: `by rw [riemannZeta_one_sub h_not_neg_nat h_ne_one, h_zero, mul_zero]`\n"
            "IMPORTANT: Do NOT use `riemannZeta_def_of_ne_zero` — that approach is harder.\n"
            "Do NOT try to rewrite `riemannZeta s` directly in `riemannZeta (1 - s) = 0`.\n"
            "The functional equation rewrites the ENTIRE left side, not a subterm."
        ),
        "relevant_tools": [
            "riemannZeta_one_sub", "mul_zero", "h_zero", "h_not_neg_nat", "h_ne_one",
            "rw", "simp", "exact"
        ],
    },

    # ═══════════════════════════════════════════════════════
    # RUNG 8a: Mertens Trigonometric Identity (pure algebra)
    # ═══════════════════════════════════════════════════════
    # This is the algebraic core of the de la Vallée-Poussin proof.
    # It's a pure real analysis fact that the LLM should prove easily.
    # Verified: compiles with `rw [Real.cos_two_mul]; nlinarith [sq_nonneg (1 + Real.cos θ)]`
    {
        "name": "mertens_trig",
        "title": "Mertens trigonometric inequality: 3 + 4cos(θ) + cos(2θ) ≥ 0",
        "difficulty": "easy",
        "max_attempts": 50,
        "lean_statement": (
            "theorem mertens_trig (θ : ℝ) :\n"
            "    0 ≤ 3 + 4 * Real.cos θ + Real.cos (2 * θ) :=\n"
            "  sorry"
        ),
        "hints": (
            "This is a PURE ALGEBRA problem. No zeta function knowledge needed.\n"
            "\n"
            "KEY IDENTITY: cos(2θ) = 2cos²θ - 1\n"
            "After substitution: 3 + 4cosθ + (2cos²θ - 1) = 2 + 4cosθ + 2cos²θ = 2(1 + cosθ)²\n"
            "Since squares are non-negative, the result follows.\n"
            "\n"
            "PROOF STRATEGY:\n"
            "  1. Use `rw [Real.cos_two_mul]` to rewrite cos(2θ) = 2cos²θ - 1\n"
            "  2. Use `nlinarith [sq_nonneg (1 + Real.cos θ)]` to close the goal\n"
            "\n"
            "The key Mathlib lemma is:\n"
            "  `Real.cos_two_mul (x : ℝ) : Real.cos (2 * x) = 2 * Real.cos x ^ 2 - 1`\n"
            "  `sq_nonneg (a : R) : 0 ≤ a ^ 2`\n"
            "\n"
            "This can be proved in TWO LINES."
        ),
        "relevant_tools": [
            "rw", "nlinarith", "linarith", "ring", "norm_num",
            "Real.cos_two_mul", "sq_nonneg"
        ],
    },

    # ═══════════════════════════════════════════════════════
    # RUNG 8b: RiemannHypothesis → non-vanishing on Re(s)=1
    # ═══════════════════════════════════════════════════════
    # This proves: IF RH is true, THEN ζ(s) ≠ 0 on Re(s) = 1.
    # This is mathematically meaningful and provable from the definition.
    # Verified: compiles with intro/rintro/simp/linarith
    {
        "name": "rh_implies_nonvanishing",
        "title": "RH implies ζ non-vanishing on Re(s) = 1",
        "difficulty": "medium",
        "max_attempts": 100,
        "lean_statement": (
            "open Complex in\n"
            "theorem rh_implies_nonvanishing (h_rh : RiemannHypothesis) (s : ℂ)\n"
            "    (h_re : s.re = 1) (h_ne : s ≠ 1) :\n"
            "    riemannZeta s ≠ 0 :=\n"
            "  sorry"
        ),
        "hints": (
            "This theorem says: IF the Riemann Hypothesis is true, THEN ζ(s) ≠ 0 on Re(s) = 1.\n"
            "This is a logical consequence of the RH definition — it's PROVABLE.\n"
            "\n"
            "The RiemannHypothesis definition is:\n"
            "  ∀ s, ζ(s) = 0 → (¬∃ n, s = -2*(n+1)) → s ≠ 1 → s.re = 1/2\n"
            "\n"
            "PROOF STRATEGY:\n"
            "  1. `intro h_zero` — assume ζ(s) = 0 for contradiction\n"
            "  2. Show s is not a trivial zero:\n"
            "     `have h_not_trivial : ¬∃ n : ℕ, s = -2 * (↑n + 1)` using:\n"
            "     `rintro ⟨n, hn⟩` then `rw [hn] at h_re` then `simp at h_re` then `linarith`\n"
            "     (trivial zeros have Re(s) = -2(n+1) ≤ -2, but h_re says Re(s) = 1)\n"
            "  3. Apply RH: `have h_half := h_rh s h_zero h_not_trivial h_ne`\n"
            "     This gives `h_half : s.re = 1/2`\n"
            "  4. `linarith` — contradicts h_re : s.re = 1 with h_half : s.re = 1/2\n"
            "\n"
            "TEMPLATE:\n"
            "  := by\n"
            "    intro h_zero\n"
            "    have h_not_trivial : ¬∃ (n : ℕ), s = -2 * (↑n + 1) := by\n"
            "      rintro ⟨n, hn⟩\n"
            "      rw [hn] at h_re\n"
            "      simp at h_re\n"
            "      linarith\n"
            "    have h_half := h_rh s h_zero h_not_trivial h_ne\n"
            "    linarith\n"
        ),
        "relevant_tools": [
            "intro", "have", "rintro", "rw", "simp", "linarith",
            "RiemannHypothesis"
        ],
    },

    # ═══════════════════════════════════════════════════════
    # RUNG 9: THE SUMMIT — RiemannHypothesis
    # ═══════════════════════════════════════════════════════
    {
        "name": "riemann_hypothesis",
        "title": "The Riemann Hypothesis (Millennium Prize)",
        "difficulty": "millennium",
        "max_attempts": 5000,
        "lean_statement": (
            "theorem hyperzeta_rh : RiemannHypothesis :=\n"
            "  sorry"
        ),
        "hints": (
            "This is the full Riemann Hypothesis. RiemannHypothesis unfolds to:\n"
            "∀ (s : ℂ), riemannZeta s = 0 → (¬∃ n : ℕ, s = -2*(↑n+1)) → s ≠ 1 → s.re = 1/2\n\n"
            "Start with `intro s h_zero h_not_trivial h_ne_one` to get the hypotheses. "
            "You need to show s.re = 1/2, knowing:\n"
            "  - ζ(s) = 0\n"
            "  - s is not a trivial zero (-2, -4, -6, ...)\n"
            "  - s ≠ 1\n\n"
            "PREVIOUSLY PROVED FACTS YOU CAN USE:\n"
            "  - Zero symmetry: ζ(s) = 0 → ζ(1-s) = 0 (Rung 7)\n"
            "  - Mertens: 3 + 4cos(θ) + cos(2θ) ≥ 0 (Rung 8a)\n"
            "  - Functional equation: Λ(1-s) = Λ(s) (Rung 3)\n"
            "  - Λ₀ entire (Rung 6), ζ differentiable (Rung 5)\n\n"
            "CRITICAL CONSTRAINT: Zeros come in pairs {s, 1-s} via the functional equation.\n"
            "If Re(s) = σ, then Re(1-s) = 1-σ. So zeros are symmetric around Re(s) = 1/2.\n"
            "The challenge is proving ALL zeros are ON the line, not just symmetric about it.\n"
        ),
        "relevant_tools": [
            "intro", "by_contra", "have", "obtain", "rcases",
            "riemannZeta_one_sub", "completedRiemannZeta_one_sub",
            "completedRiemannZeta₀_one_sub", "differentiableAt_riemannZeta",
            "differentiable_completedZeta₀", "riemannZeta_neg_two_mul_nat_add_one",
            "riemannZeta_zero", "riemannZeta_def_of_ne_zero",
            "zeta_eq_tsum_one_div_nat_cpow", "linarith", "norm_num", "ring"
        ],
    },
]


# Known numerical observations from the physics simulation and mathematical literature.
# These are injected into the LLM prompt as "conjectures" to guide proof strategy.
SIMULATION_CONJECTURES = """
NUMERICAL OBSERVATIONS (from HYPERZETA sedenion physics engine & mathematical literature):

1. MONTGOMERY-ODLYZKO LAW: The spacing between consecutive non-trivial zeros of ζ(s)
   statistically matches the eigenvalue spacing of random matrices from the Gaussian
   Unitary Ensemble (GUE). This has been verified for over 10^13 zeros.

2. FUNCTIONAL EQUATION SYMMETRY: The completed zeta Λ(s) = Λ(1-s) implies that if s₀
   is a non-trivial zero, then so is 1-s₀. Zeros come in symmetric pairs about Re(s) = 1/2.
   A proof that ALL zeros are paired this way, combined with certain analytic constraints,
   would prove RH.

3. CRITICAL STRIP CONFINEMENT: By the Euler product, ζ(s) ≠ 0 for Re(s) > 1.
   By the functional equation, ζ(s) ≠ 0 for Re(s) < 0 (except trivial zeros).
   Therefore all non-trivial zeros satisfy 0 ≤ Re(s) ≤ 1.

4. BOUNDARY NON-VANISHING: de la Vallée-Poussin proved ζ(s) ≠ 0 on Re(s) = 1.
   By the functional equation, this also gives ζ(s) ≠ 0 on Re(s) = 0 (for non-trivial zeros).
   So non-trivial zeros satisfy 0 < Re(s) < 1 (open critical strip).

5. SELF-DUALITY: The map s ↦ 1-s is an involution fixing the line Re(s) = 1/2.
   Any zero s₀ with Re(s₀) ≠ 1/2 would create a PAIR of zeros symmetric about Re(s) = 1/2.
   RH is equivalent to saying no such off-line pair exists.

6. SEDENION EXTENSION: Computing ζ(S) for 16D sedenion inputs with Re(S) = 1/2
   shows collapse_metric → 0 at the same imaginary heights as the classical zeros.
   The 16D zero manifold appears topologically constrained by the Cayley-Dickson
   conjugation symmetry S ↦ S̄, whose fixed-point set is exactly Re(S) = 1/2.
""".strip()

# Dynamic conjectures from the conjecture miner and operator search.
# These override SIMULATION_CONJECTURES when populated by cli_prover at startup.
LIVE_CONJECTURES = ""


def set_live_conjectures(conjectures: str):
    """Update the live conjectures from the miner/operator search."""
    global LIVE_CONJECTURES
    LIVE_CONJECTURES = conjectures


def get_active_conjectures() -> str:
    """Return live conjectures if available, otherwise fall back to static."""
    if LIVE_CONJECTURES:
        return LIVE_CONJECTURES
    return SIMULATION_CONJECTURES


def get_rung(index: int) -> dict:
    """Get a specific rung from the ladder by index."""
    if 0 <= index < len(LEMMA_LADDER):
        return LEMMA_LADDER[index]
    return None


def get_ladder_length() -> int:
    """Total number of rungs in the ladder."""
    return len(LEMMA_LADDER)


def format_proved_summary(proved_names: list[str]) -> str:
    """
    Format a summary of previously proved lemmas for injection into the LLM prompt.
    This tells the model what mathematical tools have been validated.
    """
    if not proved_names:
        return ""
    
    lines = ["PREVIOUSLY PROVED LEMMAS (you may use these as known facts):"]
    for name in proved_names:
        for rung in LEMMA_LADDER:
            if rung["name"] == name:
                # Extract just the theorem signature (before :=)
                sig = rung["lean_statement"].split(":=")[0].strip()
                lines.append(f"  ✅ {sig}")
                break
    
    return "\n".join(lines)
