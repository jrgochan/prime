# To The Theorist — SITREP: The Dedekind Reconnaissance (Attack 10)

**Date:** April 12, 2026, 8:24 PM MDT  
**From:** Antigravity  
**To:** The Theorist & Jason  
**Subject:** The Off-Diagonal Partition Is 1D — Season 2 May Be Short

---

## I. Executive Summary

We ran a high-precision (256-bit) piecewise decomposition of the off-diagonal Vasyunin integral:

$$\int_0^1 \left\{\frac{1}{jx}\right\} \cdot \left\{\frac{1}{kx}\right\} dx$$

for 10 different $(j,k)$ pairs covering coprime, non-coprime, and divisibility cases.

**The key discovery: the "2D partition" is actually 1D.**

Each $m$-row (where $\lfloor 1/(jx) \rfloor = m$) maps to at most **2** values of $n$ (where $\lfloor 1/(kx) \rfloor = n$), following a precise **Beatty sequence** rule:

$$n \in \left(\frac{jm}{k} - 1,\ \frac{j(m+1)}{k}\right)$$

This was verified with **100% accuracy** across all test cases. The off-diagonal proof may be dramatically simpler than the 50-hour estimate.

---

## II. The Experiment

**File:** `experiments/vasyunin/src/attack10.rs`  
**Precision:** 256-bit (rug/MPFR)  
**Method:** 
1. For each $(j,k)$, decompose $(0,1]$ into 2D tiles where both $\lfloor 1/(jx) \rfloor$ and $\lfloor 1/(kx) \rfloor$ are constant
2. Evaluate each tile integral via FTC: $\int (1/(jx) - m)(1/(kx) - n)\, dx$
3. Sum tiles and compare against the closed-form Vasyunin cotangent formula
4. Analyze the tile pattern: which $n$-values appear for each $m$?

---

## III. Results

### Convergence (piecewise sum → closed form)

| Pair | Cutoff | Tiles | Error |
|------|--------|-------|-------|
| G(1,2) | M≤100 | 100 | 2.9e-3 |
| G(1,2) | M≤500 | 500 | 5.8e-4 |
| G(2,3) | M≤100 | 135 | 1.3e-3 |
| G(2,3) | M≤500 | 668 | 2.6e-4 |
| G(3,5) | M≤100 | 141 | 8.4e-4 |
| G(3,5) | M≤500 | 701 | 1.7e-4 |

**Rate: O(1/M)** — identical to the diagonal case.

### Tile Pattern

| Pair | d | j' | k' | Max n per m | Rows with 2 tiles | Prediction |
|------|---|----|----|-------------|-------------------|----|
| G(1,2) | 1 | 1 | 2 | 1 | 0/1001 | ✅ |
| G(2,3) | 1 | 2 | 3 | 2 | 334/1001 | ✅ |
| G(3,5) | 1 | 3 | 5 | 2 | 400/1001 | ✅ |
| G(2,4) | 2 | 1 | 2 | 1 | 0/501 | ✅ |
| G(4,6) | 2 | 2 | 3 | 2 | 167/501 | ✅ |

---

## IV. The Discovery: Beatty Sequence Structure

### The Tile Rule

For a given $m \geq 1$ (with $\lfloor 1/(jx) \rfloor = m$), the set of $n$ values where the tile is nonempty is exactly:

$$n \in \mathbb{Z} \cap \left(\frac{jm}{k} - 1,\quad \frac{j(m+1)}{k}\right)$$

This interval has **width** $j/k$, so it contains:
- **Exactly 1 integer** when $jm/k$ is not an integer (generic case)
- **Exactly 2 integers** when $jm/k$ crosses an integer boundary

### When Do Splits Occur?

For coprime $j' = j/d$, $k' = k/d$:
- A single-tile row occurs when $\lfloor jm/k \rfloor = \lfloor j(m+1)/k \rfloor - 1$ or they're equal
- A double-tile (split) row occurs when $k' | (j'm + r)$ for certain residues $r$

The split pattern is **periodic with period $k'$**. For G(2,3): splits occur at $m \equiv 1 \pmod{3}$.

### Why This Matters

The "2D partition" that seemed scary is actually a **Farey-mediant / Beatty sequence** structure. Instead of $O(M^2)$ tiles, we have $O(M)$ tiles. The sum is:

$$\int_0^1 \{1/(jx)\}\{1/(kx)\}\, dx = \sum_{m=1}^{\infty} \sum_{n \in S(m)} \int_{\text{tile}(m,n)} (1/(jx) - m)(1/(kx) - n)\, dx$$

where $|S(m)| \leq 2$ for all $m$.

---

## V. What This Means for the Formal Proof

### The Diagonal Case (what we already proved)
```
For each m: one tile, one FTC evaluation, telescope
```

### The Off-Diagonal Case (what we now see)
```
For each m: one or two tiles, one or two FTC evaluations, telescope
```

The structure is **nearly identical**. The key new ingredients needed:

1. **Tile existence lemma**: For $m \geq 1$ and $n \in (jm/k - 1, j(m+1)/k) \cap \mathbb{Z}$, the tile $(m,n)$ is nonempty, with endpoints:
   $$\text{lo} = \max\left(\frac{1}{j(m+1)}, \frac{1}{k(n+1)}\right), \quad \text{hi} = \min\left(\frac{1}{jm}, \frac{1}{kn}\right)$$

2. **Cross-term FTC**: Identical to what we already have — integrate $(1/(jx) - m)(1/(kx) - n)$ on each tile. This is a product of two linear-in-$1/x$ terms, giving antiderivative:
   $$F(x) = -\frac{1}{jkx} - \left(\frac{n}{j} + \frac{m}{k}\right)\ln x + mn \cdot x$$

3. **Telescope**: Sum the tile integrals. The $-1/(jkx)$ terms telescope (boundary cancellation). The $mn \cdot x$ terms telescope. The **log terms** are the only non-trivial part.

4. **The log terms → cotangent sums**: This is where Dedekind reciprocity lives. The accumulated log coefficients $-(n/j + m/k)$ across the tiles, weighted by $\ln(\text{hi}/\text{lo})$, must assemble into the Vasyunin cotangent sums $V(j',k')$.

### The Difficulty Gradient

| Step | Difficulty | Infrastructure |
|------|-----------|----------------|
| Tile existence | ⬛ Easy | Floor arithmetic |
| Cross-term FTC | ⬛ Easy | PiecewiseFTC template |
| Telescope | ⬛⬛ Medium | Same as diagonal |
| Log → cotangent | ⬛⬛⬛ Hard | NEW — this is the Dedekind step |

The **only genuinely new mathematics** is Step 4: showing that the log terms assemble into cotangent sums. Everything else follows the exact pattern we already formalized.

---

## VI. Revised Estimate

| Path A component | Old estimate | New estimate | Reason |
|------------------|-------------|-------------|--------|
| 2D partition | 10 hrs | 3 hrs | It's actually 1D |
| Cross-term FTC | 8 hrs | 3 hrs | Template exists |
| Telescope | 5 hrs | 3 hrs | Same as diagonal |
| Cotangent emergence | 25 hrs | 15-20 hrs | Still hard, but constrained |
| **Total** | **~50 hrs** | **~25 hrs** | **Cut in half** |

The Beatty structure simplifies everything except the cotangent emergence, which is an irreducible number-theoretic identity.

---

## VII. Recommendation

The reconnaissance is complete. The off-diagonal territory is **far more hospitable than we feared**. The piecewise decomposition is 1D (not 2D), the FTC is identical to what we have, and the only hard part is the cotangent assembly.

When Season 2 opens, Attack 10 is the map. The experiment is saved at `experiments/vasyunin/src/attack10.rs` with full output at `output_attack10.log`.

For now — the gates remain locked. The 3-Axiom Cathedral stands. But when the time comes, we know exactly where to dig.

---

*"The map is not the territory — but a good map makes all the difference."*

— Antigravity
