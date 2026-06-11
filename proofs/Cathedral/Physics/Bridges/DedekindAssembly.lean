/-
  Cathedral/Physics/Bridges/DedekindAssembly.lean

  # Dedekind Sum Assembly — Resolving the Circular Dependency

  ## Purpose

  This file resolves the file-ordering artifact between DedekindReciprocity.lean
  and DedekindBridge.lean. The three-term relation for r ≥ 2 is proved in
  DedekindBridge.lean (via the Brave Berry 🍓), but DedekindReciprocity.lean
  cannot import DedekindBridge (circular dependency).

  This assembly file imports both and provides the sorry-free three-term relation.

  ## Architecture

  DedekindReciprocity.lean  ──imports──→  DedekindBridge.lean
         ↓                                      ↓
         └──────────────→  DedekindAssembly.lean ←──┘
                           (sorry-free three_term)
-/

import Cathedral.Physics.Bridges.DedekindBridge

namespace Cathedral.Physics.DedekindBridge

open Finset BigOperators

/-- **THREE-TERM RELATION** (sorry-free assembly):

    12·a·b·r·(s(a,b) - s(a,r)) = r·(a²+b²+1) - b·(a²+r²+1)

    where r = b % a. This is the same statement as
    `dedekind_three_term` in DedekindReciprocity.lean,
    but proved sorry-free by importing from DedekindBridge.lean.

    The proof for r = 1 uses cross-sum expansion.
    The proof for r ≥ 2 uses the Brave Berry 🍓 (weighted_floor_base)
    and Euclidean descent (weighted_floor_step). -/
theorem dedekind_three_term_assembled (a b : ℕ) (ha : 1 < a) (hb : 1 < b)
    (hr : 0 < b % a) (hcop : Nat.Coprime a b) :
    12 * (a : ℝ) * b * ((b % a : ℕ) : ℝ) * (dedekindSum a b - dedekindSum a (b % a)) =
    ((b % a : ℕ) : ℝ) * ((a : ℝ)^2 + (b : ℝ)^2 + 1) -
    (b : ℝ) * ((a : ℝ)^2 + ((b % a : ℕ) : ℝ)^2 + 1) :=
  dedekind_three_term_full a b ha hb hr hcop

end Cathedral.Physics.DedekindBridge
