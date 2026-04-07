import Cathedral.MellinBridge.Basic
import Cathedral.MellinBridge.FloorMellin
import Cathedral.MellinBridge.FloorDivMellin
import Cathedral.MellinBridge.Separation
import Cathedral.MellinBridge.NymanBeurling
import Cathedral.MellinBridge.HilbertSetup
import Cathedral.MellinBridge.OrthogonalWitness

/-! # Cathedral.MellinBridge

Re-export hub for the MellinBridge module. This file imports all
submodules so that `import Cathedral.MellinBridge` continues to work
as a single import for downstream files (e.g. `Cathedral.Assembly`).

## Submodules
- **Basic**: Definitions (`mellinRestricted`, `fractBasisC`, `targetFnC`), `mellin_target`
- **FloorMellin**: k=1 floor Mellin transform, `floor_mellin_eq_zeta`
- **FloorDivMellin**: k≥1 generalized, `floor_div_mellin`, `mellin_fractBasis`
- **Separation**: Separating functional, zeta non-vanishing, `nyman_beurling_converse`
- **NymanBeurling**: Forward direction, combined criterion, immediate results
- **HilbertSetup**: L² Hilbert space infrastructure
- **OrthogonalWitness**: Báez-Duarte witness, defeats the Hyperplane Trap
-/

