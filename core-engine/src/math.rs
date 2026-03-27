//! Cayley-Dickson Algebra Module
//! Implements strict 64-bit precision floating-point arithmetic for Non-Associative geometries.

#[derive(Clone, Copy, Debug)]
pub struct Quaternion {
    pub r: f64,
    pub i: f64,
    pub j: f64,
    pub k: f64,
}

impl Quaternion {
    pub fn new(r: f64, i: f64, j: f64, k: f64) -> Self {
        Self { r, i, j, k }
    }
    
    pub fn conjugate(&self) -> Self {
        Self::new(self.r, -self.i, -self.j, -self.k)
    }

    pub fn mul(&self, other: &Self) -> Self {
        Self::new(
            self.r * other.r - self.i * other.i - self.j * other.j - self.k * other.k,
            self.r * other.i + self.i * other.r + self.j * other.k - self.k * other.j,
            self.r * other.j - self.i * other.k + self.j * other.r + self.k * other.i,
            self.r * other.k + self.i * other.j - self.j * other.i + self.k * other.r,
        )
    }
    
    pub fn add(&self, other: &Self) -> Self {
        Self::new(self.r + other.r, self.i + other.i, self.j + other.j, self.k + other.k)
    }

    pub fn sub(&self, other: &Self) -> Self {
        Self::new(self.r - other.r, self.i - other.i, self.j - other.j, self.k - other.k)
    }

    pub fn norm_sq(&self) -> f64 {
        self.r * self.r + self.i * self.i + self.j * self.j + self.k * self.k
    }

    pub fn scale(&self, s: f64) -> Self {
        Self::new(self.r * s, self.i * s, self.j * s, self.k * s)
    }
}

// Octonion (Pair of Quaternions)
#[derive(Clone, Copy, Debug)]
pub struct Octonion {
    pub a: Quaternion,
    pub b: Quaternion,
}

impl Octonion {
    pub fn new(a: Quaternion, b: Quaternion) -> Self {
        Self { a, b }
    }

    pub fn conjugate(&self) -> Self {
        Self::new(self.a.conjugate(), Self::negate_quat(&self.b))
    }

    fn negate_quat(q: &Quaternion) -> Quaternion {
        Quaternion::new(-q.r, -q.i, -q.j, -q.k)
    }

    pub fn mul(&self, other: &Self) -> Self {
        let ac = self.a.mul(&other.a);
        let d_star = other.b.conjugate();
        let d_star_b = d_star.mul(&self.b);
        let first = ac.sub(&d_star_b);

        let da = other.b.mul(&self.a);
        let c_star = self.a.conjugate(); 
        let bc_star = self.b.mul(&c_star);
        let second = da.add(&bc_star);

        Self::new(first, second)
    }
    
    pub fn add(&self, other: &Self) -> Self {
        Self::new(self.a.add(&other.a), self.b.add(&other.b))
    }
    
    pub fn sub(&self, other: &Self) -> Self {
        let first_a = self.a.sub(&other.a);
        let second_b = self.b.sub(&other.b);
        Self::new(first_a, second_b)
    }

    pub fn norm_sq(&self) -> f64 {
        self.a.norm_sq() + self.b.norm_sq()
    }

    pub fn scale(&self, s: f64) -> Self {
        Self::new(self.a.scale(s), self.b.scale(s))
    }
}

// Sedenion (Pair of Octonions)
#[derive(Clone, Copy, Debug)]
pub struct Sedenion {
    pub a: Octonion,
    pub b: Octonion,
}

impl Sedenion {
    pub fn new(a: Octonion, b: Octonion) -> Self {
        Self { a, b }
    }
    
    pub fn zero() -> Self {
        Sedenion::new(
            Octonion::new(
                Quaternion::new(0.0, 0.0, 0.0, 0.0), 
                Quaternion::new(0.0, 0.0, 0.0, 0.0)
            ),
            Octonion::new(
                Quaternion::new(0.0, 0.0, 0.0, 0.0), 
                Quaternion::new(0.0, 0.0, 0.0, 0.0)
            )
        )
    }

    pub fn add(&self, other: &Self) -> Self {
        Self::new(self.a.add(&other.a), self.b.add(&other.b))
    }

    pub fn sub(&self, other: &Self) -> Self {
        Self::new(self.a.sub(&other.a), self.b.sub(&other.b))
    }

    pub fn mul(&self, other: &Self) -> Self {
        let ac = self.a.mul(&other.a);
        let d_star = other.b.conjugate();
        let d_star_b = d_star.mul(&self.b);
        let first = ac.sub(&d_star_b);

        let da = other.b.mul(&self.a);
        let c_star = self.a.conjugate();
        let bc_star = self.b.mul(&c_star);
        let second = da.add(&bc_star);

        Self::new(first, second)
    }

    pub fn norm_sq(&self) -> f64 {
        self.a.norm_sq() + self.b.norm_sq()
    }

    pub fn scale(&self, s: f64) -> Self {
        Self::new(self.a.scale(s), self.b.scale(s))
    }

    pub fn normalize(&self) -> Self {
        let n = self.norm_sq().sqrt();
        if n == 0.0 {
            *self
        } else {
            self.scale(1.0 / n)
        }
    }

    /// Evaluates the Euler Hypercomplex Exponential e^S
    /// e^S = e^r * (cos(|V|) + (V / |V|) * sin(|V|))
    pub fn exp(&self) -> Self {
        let r = self.a.a.r; // The real scalar boundary
        
        let mut v = *self;
        v.a.a.r = 0.0; // Isolate the 15-Dimensional Imaginary Vector V

        let v_norm = v.norm_sq().sqrt();
        let exp_r = r.exp();

        if v_norm == 0.0 {
            // Strictly real bound return
            let mut res = Sedenion::zero();
            res.a.a.r = exp_r;
            return res;
        }

        let cos_v = v_norm.cos();
        let sin_v_over_v = v_norm.sin() / v_norm;

        // V * (sin(|V|) / |V|)
        let mut scaled_v = v.scale(sin_v_over_v);
        
        // Add cos(|V|) to the real axis position
        scaled_v.a.a.r += cos_v;

        // Multiply magnitude entirely by e^R exponential drift
        scaled_v.scale(exp_r)
    }
}
