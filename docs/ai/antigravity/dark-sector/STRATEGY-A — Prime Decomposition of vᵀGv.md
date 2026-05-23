# Strategy A — Prime Decomposition of vᵀGv

## Goal

Prove `vᵀGv ≤ 1` for the Möbius-weighted vector `v = bdMoebiusWeight N` by decomposing the quadratic form along prime residue classes and using the spectral self-similarity bound.

## The Idea

The key insight from PrimeFractal is the **spectral self-similarity**:

$$\lambda_{\min}(G^{(p)}_N) \leq \frac{1}{p} \cdot \lambda_{\min}(G_N) + \frac{p-1}{p}$$

This says the prime-restricted Gram matrix (restricting basis functions to multiples of p) has eigenvalues bounded by a linear contraction of the full matrix's eigenvalues.

**Can we decompose vᵀGv by prime?** If the Gram matrix decomposes as:

$$G = \sum_{p \text{ prime}} (\text{contribution from multiples of } p) + (\text{cross terms})$$

and each prime's contribution is bounded by the self-similarity, then the sum might telescope.

## Cathedral Arsenal

### Already Proved (0 sorry)

| Theorem | File | Statement |
|---------|------|-----------|
| `quadForm_primeGram_bound` | PrimeFractal.lean | vᵀG_p v ≤ (1/p)·vᵀGv + (p-1)/p |
| `spectral_selfsimilarity_upper` | PrimeFractal.lean | λ_min(G^(p)) ≤ (1/p)·λ_min(G) + (p-1)/p |
| `primeGramEntry_split` | PrimeFractal.lean | G_p(j,k) = (1/p)·G(j,k) + E(j,k) |
| `primeGramEntry_error_decay_tight` | PrimeFractal.lean | \|E(j,k)\| ≤ (p-1)/(jkp²) |
| `gram_entry_cauchy_schwarz` | GramBridge.lean | G_{jk}² ≤ G_{jj}·G_{kk} |
| `gram_offdiag_abs_bound` | PrimeDecoupling.lean | \|G(j,k)\| ≤ (3/4)(1/j + 1/k) |
| `eigenvalue_interlacing` | Eigenvalue.lean | λ_min(G_{N+1}) ≤ λ_min(G_N) |
| `eigenvalue_limit_exists` | MainChain.lean | ∃ L ≥ 0, λ_min(N) → L |

### Key Missing Pieces

1. **Gram decomposition by divisibility**: Express G(j,k) as a sum over primes dividing gcd(j,k). Mathlib has `Nat.divisors`, `Nat.factorization`, and Möbius inversion. The key identity would be:

   $$G(j,k) = \sum_{d | \gcd(j,k)} f(d)$$

   for some arithmetic function f. The Gram entry is $\int_0^1 \{1/(jx)\}\{1/(kx)\} dx$, and the substitution $u = dx$ might factor by divisors.

2. **Prime sieve for the quadratic form**: The Möbius vector v_k = μ(k)/log(N) is supported on squarefree k. By Möbius inversion, μ(k) decomposes as a product over primes dividing k. This could give:

   $$v^T G v = \sum_{k,\ell} \frac{\mu(k)\mu(\ell)}{(\log N)^2} G(k,\ell) = \text{sieve expression}$$

3. **Buchstab/Selberg sieve connection**: The quadratic form vᵀGv with Möbius weights is essentially a sieve object. The Selberg sieve gives upper bounds on such forms.

## Proof Sketch

### Step 1: Express G via Ramanujan sums

The Gram entry has the Vasyunin formula:

$$G(j,k) = \frac{\ln(2\pi) - \gamma}{\text{lcm}(j,k)} - \frac{1}{jk} + \text{(cotangent correction)}$$

The leading term 1/lcm(j,k) decomposes by prime factorization:

$$\frac{1}{\text{lcm}(j,k)} = \frac{\gcd(j,k)}{jk} = \frac{1}{jk} \sum_{d | \gcd(j,k)} \varphi(d)/d$$

(using Euler's totient). This is proved in `DedekindBridge.lean`.

### Step 2: Substitute Möbius weights

For the Möbius vector, the convolution μ * μ has known properties:

$$\sum_{k,\ell} \frac{\mu(k)\mu(\ell)}{k\ell} \cdot \frac{\gcd(k,\ell)}{k\ell} = \sum_d \frac{1}{d} \left(\sum_{k: d|k} \frac{\mu(k)}{k}\right)^2$$

The inner sum Σ_{k: d|k} μ(k)/k is a truncated Euler product, bounded by the Mertens estimates.

### Step 3: Apply self-similarity recursion

For each prime p, the contribution from multiples of p satisfies:

$$\sum_{\substack{j,k \\ p|j, p|k}} v_j G(j,k) v_k \leq \frac{1}{p} \cdot v^T G v + \frac{p-1}{p} \cdot \|v_p\|^2$$

where $v_p$ is the restriction of v to multiples of p. Summing over primes with inclusion-exclusion...

### Step 4: Telescoping

If the recursion converges, we get:

$$v^T G v \leq \prod_p \left(1 + \frac{1}{p}\right) \cdot (\text{base term})$$

The product Π(1 + 1/p) relates to ζ(1) — it diverges. So the naive version doesn't close.

## Difficulty Assessment

> [!WARNING]
> **HIGH DIFFICULTY.** The prime decomposition of the quadratic form requires:
> - Inclusion-exclusion over prime sets (Möbius inversion on the divisor lattice)
> - Control of cross terms between different prime classes
> - The naive recursion diverges — need a more refined bound

The self-similarity bound is an **inequality** not an identity, so the recursion loses information at each step. The key challenge is making the bound tight enough that the product over primes converges.

## Estimated Effort

- **Research**: 2-3 days to determine if the decomposition converges
- **Formalization**: 5-10 days if the mathematics works out
- **Risk**: Medium-High — the divergence of Π(1 + 1/p) suggests the naive strategy fails

## Recommendation

This strategy is **mathematically beautiful** but likely requires a more refined version of the self-similarity bound — perhaps one that accounts for the specific structure of the Möbius vector rather than arbitrary vectors. The `primeGramEntry_error_decay_tight` bound (which uses (p-1)/(jkp²) instead of (p-1)/(jkp)) might be tight enough, but verifying this requires careful analysis of the double sums.

**Best next step**: Write a numerical experiment computing Σ_p (prime contribution to vᵀGv) and check whether the per-prime contributions decay fast enough.
