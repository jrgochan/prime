//! Double-double arithmetic: ~106-bit precision using two f64s.
//!
//! Represents a number as x = hi + lo where |lo| ≤ 0.5 ulp(hi).
//! This gives ~31 decimal digits of precision using only native f64 hardware.
//!
//! Reference: Hida, Li, Bailey — "Library for Double-Double and Quad-Double Arithmetic" (2001)

/// A double-double number: hi + lo with |lo| ≤ 0.5 ulp(hi).
#[derive(Debug, Clone, Copy)]
pub struct DD {
    pub hi: f64,
    pub lo: f64,
}

impl DD {
    #[inline]
    pub const fn new(hi: f64, lo: f64) -> Self {
        Self { hi, lo }
    }

    #[inline]
    pub fn from_f64(x: f64) -> Self {
        Self { hi: x, lo: 0.0 }
    }

    #[inline]
    pub fn from_u64(x: u64) -> Self {
        let hi = x as f64;
        let lo = (x as i128 - hi as i128) as f64;
        Self { hi, lo }
    }

    #[inline]
    pub fn to_f64(self) -> f64 {
        self.hi + self.lo
    }

    /// Error-free sum of two f64s: returns (s, e) where a + b = s + e exactly.
    #[inline]
    fn two_sum(a: f64, b: f64) -> (f64, f64) {
        let s = a + b;
        let v = s - a;
        let e = (a - (s - v)) + (b - v);
        (s, e)
    }

    /// Error-free product of two f64s: returns (p, e) where a * b = p + e exactly.
    #[inline]
    fn two_prod(a: f64, b: f64) -> (f64, f64) {
        let p = a * b;
        let e = a.mul_add(b, -p); // FMA instruction on M2
        (p, e)
    }

    /// Quick two-sum (assumes |a| >= |b|).
    #[inline]
    fn quick_two_sum(a: f64, b: f64) -> (f64, f64) {
        let s = a + b;
        let e = b - (s - a);
        (s, e)
    }

    pub fn abs(self) -> Self {
        if self.hi < 0.0 { -self } else { self }
    }
}

// ═══ Addition ═══

impl std::ops::Add for DD {
    type Output = DD;
    #[inline]
    fn add(self, rhs: DD) -> DD {
        let (s1, e1) = DD::two_sum(self.hi, rhs.hi);
        let e1 = e1 + self.lo + rhs.lo;
        let (hi, lo) = DD::quick_two_sum(s1, e1);
        DD { hi, lo }
    }
}

impl std::ops::AddAssign for DD {
    #[inline]
    fn add_assign(&mut self, rhs: DD) {
        *self = *self + rhs;
    }
}

impl std::ops::AddAssign<f64> for DD {
    #[inline]
    fn add_assign(&mut self, rhs: f64) {
        *self = *self + DD::from_f64(rhs);
    }
}

// ═══ Subtraction ═══

impl std::ops::Neg for DD {
    type Output = DD;
    #[inline]
    fn neg(self) -> DD {
        DD { hi: -self.hi, lo: -self.lo }
    }
}

impl std::ops::Sub for DD {
    type Output = DD;
    #[inline]
    fn sub(self, rhs: DD) -> DD {
        self + (-rhs)
    }
}

impl std::ops::SubAssign for DD {
    #[inline]
    fn sub_assign(&mut self, rhs: DD) {
        *self = *self - rhs;
    }
}

// ═══ Multiplication ═══

impl std::ops::Mul for DD {
    type Output = DD;
    #[inline]
    fn mul(self, rhs: DD) -> DD {
        let (p1, p2) = DD::two_prod(self.hi, rhs.hi);
        let p2 = p2 + self.hi * rhs.lo + self.lo * rhs.hi;
        let (hi, lo) = DD::quick_two_sum(p1, p2);
        DD { hi, lo }
    }
}

impl std::ops::MulAssign for DD {
    #[inline]
    fn mul_assign(&mut self, rhs: DD) {
        *self = *self * rhs;
    }
}

impl std::ops::MulAssign<f64> for DD {
    #[inline]
    fn mul_assign(&mut self, rhs: f64) {
        *self = *self * DD::from_f64(rhs);
    }
}

// ═══ Division ═══

impl std::ops::Div for DD {
    type Output = DD;
    #[inline]
    fn div(self, rhs: DD) -> DD {
        let q1 = self.hi / rhs.hi;
        let r = self - rhs * DD::from_f64(q1);
        let q2 = r.hi / rhs.hi;
        let r = r - rhs * DD::from_f64(q2);
        let q3 = r.hi / rhs.hi;
        let (hi, lo) = DD::quick_two_sum(q1, q2);
        DD { hi, lo } + DD::from_f64(q3)
    }
}

impl std::ops::DivAssign for DD {
    #[inline]
    fn div_assign(&mut self, rhs: DD) {
        *self = *self / rhs;
    }
}

// ═══ ln(1 + 1/n) for precomputed table ═══

impl DD {
    /// Compute ln(1 + 1/n) at double-double precision.
    /// Uses the series: ln(1+x) = x - x²/2 + x³/3 - x⁴/4 + ...
    /// where x = 1/n.
    pub fn ln1p_inv(n: u64) -> Self {
        let x = DD::from_f64(1.0) / DD::from_u64(n);
        let mut term = x;
        let mut sum = x;
        for k in 2..=60 {
            term *= -x;
            let contrib = term / DD::from_u64(k);
            sum += contrib;
            if contrib.hi.abs() < 1e-32 * sum.hi.abs() {
                break;
            }
        }
        sum
    }
}

#[cfg(test)]
mod tests {
    use super::DD;

    #[test]
    fn test_basic_arithmetic() {
        let a = DD::from_f64(1.0);
        let b = DD::from_f64(2.0);
        let c = a + b;
        assert!((c.to_f64() - 3.0).abs() < 1e-15);

        let d = b * DD::from_f64(3.0);
        assert!((d.to_f64() - 6.0).abs() < 1e-15);
    }

    #[test]
    fn test_ln1p_inv() {
        // ln(1 + 1/1) = ln(2) ≈ 0.693147...
        let ln2 = DD::ln1p_inv(1);
        assert!((ln2.to_f64() - 2.0_f64.ln()).abs() < 1e-15);

        // ln(1 + 1/100) ≈ 0.00995033...
        let ln101_100 = DD::ln1p_inv(100);
        assert!((ln101_100.to_f64() - (1.01_f64).ln()).abs() < 1e-15);
    }
}
