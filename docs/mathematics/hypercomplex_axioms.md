# Hypercomplex Axioms & Implementation (Rust)

Project HYPERZETA extends the Riemann Zeta function from $\mathbb{C}$ (Complex 2D) up the Cayley-Dickson construction to $\mathbb{S}$ (Sedenions 16D).

## 1. The Cayley-Dickson Algebra Degradation
As we step up in dimension, we lose foundational algebraic laws. The Rust core must strictly enforce:
1.  **Quaternions ($\mathbb{H}$ - 4D):** Loss of Commutativity ($A \times B \neq B \times A$). 
2.  **Octonions ($\mathbb{O}$ - 8D):** Loss of Associativity ($(A \times B) \times C \neq A \times (B \times C)$).
3.  **Sedenions ($\mathbb{S}$ - 16D):** Loss of Alternativity and introduction of **Zero Divisors**.

## 2. Parallel Non-Associativity (The AST Graph)
> [!CAUTION]
> The biggest trap in writing parallel Rust code for Octonions is assuming non-associative multiplication can be multi-threaded standardly. $(A \times B) \times C$ cannot be evaluated concurrently across threads because order defines the value.

*   **Implementation Rule:** The Rust backend cannot use standard `rayon` maps over raw multiplication sequences. It must compile equations into an **Abstract Syntax Tree (AST)**.
*   The AST Evaluator identifies completely independent branches of the hypercomplex polynomial, dispatches them concurrently across the Mac's 12 CPU cores, but enforces absolute sequential thread-synchronization barriers around all Non-Associative multiplication parent nodes.

## 3. Arbitrary Precision Safeguards
*   **The Flint2 Wrapper:** Because algorithms cascade logarithmically across non-associative steps, standard 64-bit floats degrade instantly. The Rust daemon must wrap `Arb` (Arbitrary-Precision Ball Arithmetic). 
*   **Ball Arithmetic:** Mathematical proofs are generated out of upper and lower bounds to prevent calculating "Phantom Sedenion Zeros."
