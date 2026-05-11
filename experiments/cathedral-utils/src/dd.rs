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

// ═══ Comparisons ═══

impl PartialEq for DD {
    fn eq(&self, other: &Self) -> bool {
        self.hi == other.hi && self.lo == other.lo
    }
}

impl PartialOrd for DD {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        match self.hi.partial_cmp(&other.hi) {
            Some(std::cmp::Ordering::Equal) => self.lo.partial_cmp(&other.lo),
            other_ord => other_ord,
        }
    }
}

// ═══ Transcendental functions ═══

impl DD {
    /// Floor function.
    pub fn floor(self) -> Self {
        let fl = self.hi.floor();
        if fl == self.hi {
            // hi is exact integer, check lo
            let lo_fl = self.lo.floor();
            DD::quick_two_sum(fl, lo_fl).into()
        } else {
            DD::from_f64(fl)
        }
    }

    /// Fractional part: {x} = x - floor(x)
    pub fn frac(self) -> Self {
        self - self.floor()
    }

    /// Natural logarithm via argument reduction + Taylor series.
    /// ln(x) = ln(m·2^e) = e·ln(2) + ln(m) where m ∈ [1,2)
    /// For ln(m): use ln(1 + (m-1)) with Padé-accelerated Taylor.
    pub fn ln(self) -> Self {
        if self.hi <= 0.0 { return DD::new(f64::NAN, 0.0); }

        // ln(2) at DD precision
        let ln2 = DD::new(
            0.6931471805599453,
            2.3190468138462996e-17,
        );

        // Argument reduction: x = m · 2^e
        let (mantissa, exp) = frexp_dd(self);
        let e = DD::from_f64(exp as f64);

        // Now compute ln(m) where m ∈ [0.5, 1.0)
        // Shift to ln(2m) - ln(2) if m < 0.75 for better convergence
        let (m, adjust) = if mantissa.hi < 0.75 {
            (mantissa + mantissa, DD::from_f64(-1.0))
        } else {
            (mantissa, DD::from_f64(0.0))
        };

        // ln(m) where m ∈ [0.75, 2.0) via ln(1 + u) where u = m - 1
        let u = m - DD::from_f64(1.0);

        // Taylor series: ln(1+u) = u - u²/2 + u³/3 - ...
        // For better convergence, use the identity:
        // ln(1+u) = 2·atanh(u/(u+2)) = 2·Σ (u/(u+2))^(2k+1)/(2k+1)
        let v = u / (u + DD::from_f64(2.0));
        let v2 = v * v;
        let mut term = v;
        let mut sum = v;
        for k in 1..=30 {
            term *= v2;
            let contrib = term / DD::from_u64(2 * k + 1);
            sum += contrib;
            if contrib.hi.abs() < 1e-32 * sum.hi.abs() { break; }
        }
        let ln_m = sum + sum; // 2·atanh

        (e + adjust) * ln2 + ln_m
    }

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

    /// Digamma function ψ(x) via recurrence + asymptotic expansion.
    /// Uses ψ(x+1) = ψ(x) + 1/x to shift x ≥ 20, then asymptotic.
    pub fn digamma(mut self) -> Self {
        if self.hi <= 0.0 { return DD::new(f64::NAN, 0.0); }

        let mut result = DD::from_f64(0.0);

        // Recurrence: shift to large argument
        while self.hi < 20.0 {
            result -= DD::from_f64(1.0) / self;
            self += DD::from_f64(1.0);
        }

        // Asymptotic: ψ(x) ≈ ln(x) - 1/(2x) - Σ B_{2k}/(2k·x^{2k})
        result += self.ln();
        let inv_x = DD::from_f64(1.0) / self;
        let inv_x2 = inv_x * inv_x;

        result -= inv_x * DD::from_f64(0.5);

        let mut x2k = inv_x2;
        // B₂/(2·1) = 1/12
        result -= x2k / DD::from_f64(12.0);
        x2k *= inv_x2;
        // -B₄/(4·2) = 1/120
        result += x2k / DD::from_f64(120.0);
        x2k *= inv_x2;
        result -= x2k / DD::from_f64(252.0);
        x2k *= inv_x2;
        result += x2k / DD::from_f64(240.0);
        x2k *= inv_x2;
        result -= x2k * DD::from_f64(5.0) / DD::from_f64(660.0);
        x2k *= inv_x2;
        result += x2k * DD::from_f64(691.0) / DD::from_f64(360360.0);
        x2k *= inv_x2;
        result -= x2k / DD::from_f64(12.0);  // B₁₄ term

        result
    }

    /// Log-gamma: ln|Γ(x)| via Stirling + recurrence.
    pub fn lgamma(mut self) -> Self {
        if self.hi <= 0.0 { return DD::new(f64::NAN, 0.0); }

        let mut prefix = DD::from_f64(0.0);

        // Recurrence: Γ(x+1) = x·Γ(x) → logΓ(x) = logΓ(x+1) - ln(x)
        while self.hi < 20.0 {
            prefix -= self.ln();
            self += DD::from_f64(1.0);
        }

        // Stirling: logΓ(x) ≈ (x-1/2)·ln(x) - x + (1/2)·ln(2π) + Σ B_{2k}/(2k(2k-1)x^{2k-1})
        let half = DD::from_f64(0.5);
        // ln(2π) at DD precision
        let ln_2pi = DD::new(1.8378770664093453, -1.0725750903041484e-16);

        let result = (self - half) * self.ln() - self + half * ln_2pi;

        // Bernoulli correction terms
        let inv_x = DD::from_f64(1.0) / self;
        let inv_x2 = inv_x * inv_x;
        let mut corr = inv_x / DD::from_f64(12.0);
        let mut x2k1 = inv_x * inv_x2;
        corr -= x2k1 / DD::from_f64(360.0);
        x2k1 *= inv_x2;
        corr += x2k1 / DD::from_f64(1260.0);
        x2k1 *= inv_x2;
        corr -= x2k1 / DD::from_f64(1680.0);
        x2k1 *= inv_x2;
        corr += x2k1 / DD::from_f64(1188.0);

        prefix + result + corr
    }

    /// Sine via Taylor series with argument reduction.
    pub fn sin(self) -> Self {
        let pi = DD::new(std::f64::consts::PI, 1.2246467991473532e-16);
        let two_pi = pi + pi;

        // Reduce to [0, 2π)
        let k = (self / two_pi).floor();
        let x = self - k * two_pi;

        // Taylor: sin(x) = x - x³/3! + x⁵/5! - ...
        let x2 = x * x;
        let mut term = x;
        let mut sum = x;
        for n in 1..=20 {
            term = term * (-x2) / DD::from_u64((2*n) * (2*n + 1));
            sum += term;
            if term.hi.abs() < 1e-32 * sum.hi.abs() { break; }
        }
        sum
    }

    /// Cosine via Taylor series with argument reduction.
    pub fn cos(self) -> Self {
        let pi = DD::new(std::f64::consts::PI, 1.2246467991473532e-16);
        let two_pi = pi + pi;

        let k = (self / two_pi).floor();
        let x = self - k * two_pi;

        let x2 = x * x;
        let mut term = DD::from_f64(1.0);
        let mut sum = DD::from_f64(1.0);
        for n in 1..=20 {
            term = term * (-x2) / DD::from_u64((2*n - 1) * (2*n));
            sum += term;
            if term.hi.abs() < 1e-32 * sum.hi.abs() { break; }
        }
        sum
    }

    /// Cotangent: cos(x)/sin(x)
    pub fn cot(self) -> Self {
        self.cos() / self.sin()
    }
}

/// Helper: extract mantissa and exponent (frexp equivalent for DD)
fn frexp_dd(x: DD) -> (DD, i32) {
    // Use the hi part for exponent extraction
    let bits = x.hi.to_bits();
    let exp = ((bits >> 52) & 0x7FF) as i32 - 1022;
    let scale = 2.0_f64.powi(-exp);
    (DD::new(x.hi * scale, x.lo * scale), exp)
}

impl From<(f64, f64)> for DD {
    fn from((hi, lo): (f64, f64)) -> Self {
        DD { hi, lo }
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
