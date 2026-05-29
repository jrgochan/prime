/-
  Scratch file to test Euler product projection from ℂ to ℝ
-/
import Mathlib.NumberTheory.EulerProduct.DirichletLSeries
import Mathlib.NumberTheory.LSeries.HurwitzZetaValues

noncomputable section
open Complex Real

-- Test: Can we get the ℂ Euler product at s = 2?
#check @riemannZeta_eulerProduct_hasProd 2 (by norm_num : 1 < (2 : ℂ).re)

-- Test: riemannZeta_two
#check riemannZeta_two -- : riemannZeta 2 = (π : ℂ) ^ 2 / 6

-- Test: ofRealHom as a MonoidHom
#check (Complex.ofRealHom : ℝ →+* ℂ)
#check (Complex.ofRealHom.toMonoidHom : ℝ →* ℂ)

-- Test: IsInducing for ofReal
#check Complex.isUniformEmbedding_ofReal
-- IsClosedEmbedding → IsInducing
#check Complex.isUniformEmbedding_ofReal.isClosedEmbedding

-- Test: HasProd.map with monoid hom
#check @HasProd.map

-- Test: IsInducing.hasProd_iff
#check @Topology.IsInducing.hasProd_iff

-- Test: cpow_neg and cpow_natCast
#check @Complex.cpow_neg
#check @Complex.cpow_natCast

-- Key lemma: for prime p, the ℂ Euler factor equals ofReal of the ℝ factor
-- (1 - (p:ℂ)^(-2))⁻¹ = ofReal((1 - 1/(p:ℝ)^2)⁻¹)
-- Steps:
-- (p:ℂ)^(-(2:ℂ)) = ((p:ℂ)^(2:ℂ))⁻¹  [cpow_neg]
-- (p:ℂ)^(2:ℂ) = (p:ℂ)^2              [cpow_natCast]
-- (p:ℂ)^2 = ofReal((p:ℝ)^2)           [ofReal_pow]
-- 1 - ofReal(x)⁻¹ = ofReal(1 - x⁻¹)  [ofReal_sub, ofReal_inv, ofReal_one]

end
