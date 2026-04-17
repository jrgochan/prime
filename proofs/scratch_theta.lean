import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.NumberTheory.LSeries.HurwitzZetaEven
import Mathlib.Analysis.Real.Pi.Bounds

noncomputable section
open Complex Real MeasureTheory Set HurwitzZeta Filter

private abbrev P₀ := (hurwitzEvenFEPair (0 : UnitAddCircle))

-- Check: P₀.Λ₀ = mellin P₀.f_modif = mellin P₀.toStrongFEPair.f
-- toStrongFEPair.f = f_modif (line 314)
-- toStrongFEPair.Λ = mellin f (line 200)
-- So P₀.toStrongFEPair.Λ = mellin P₀.toStrongFEPair.f = mellin P₀.f_modif = P₀.Λ₀

-- P₀.Λ₀ is defined as mellin P₀.f_modif
-- P₀.toStrongFEPair.Λ is defined as mellin P₀.toStrongFEPair.f = mellin P₀.f_modif

example (s : ℂ) : P₀.Λ₀ s = P₀.toStrongFEPair.Λ s := by rfl

-- So ‖P₀.Λ₀ s‖ = ‖mellin P₀.toStrongFEPair.f s‖
example (s : ℂ) : ‖P₀.Λ₀ s‖ = ‖mellin P₀.toStrongFEPair.f s‖ := by rfl

-- And the norm bound should use P₀.Λ₀ directly
example (s : ℂ) (h : ‖mellin P₀.toStrongFEPair.f s‖ < 8) :
    ‖P₀.Λ₀ s‖ < 8 := h

