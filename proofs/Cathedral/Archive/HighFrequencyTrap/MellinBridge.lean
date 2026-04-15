import Cathedral.Archive.HighFrequencyTrap.MellinBridge.Basic
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.FloorMellin
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.FloorDivMellin
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.Separation
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.HilbertSetup
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.OrthogonalWitness
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.MellinSieve
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.AbelSummation
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.MertensIntegral
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.MertensWeightBypass
import Cathedral.Archive.HighFrequencyTrap.MellinBridge.AutocorrelationBypass

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

