//! # HyperZeta Morphology Scanner
//!
//! Headless Rust binary that sweeps t from t_start → t_end,
//! computing at each step:
//!   - Shape classification (PCA + void + angular)
//!   - Matter/antimatter distribution (Möbius sign)
//!   - Jet detection (angular binning)
//!   - Cayley-Dickson layer energies
//!   - Collapse metric
//!
//! Outputs one JSON record per t-step to stdout (JSON Lines format).
//! Designed for piping into analysis scripts.

mod math;

use clap::Parser;
use math::{Quaternion, Octonion, Sedenion};
use rand::Rng;
use rand::SeedableRng;
use rand_chacha::ChaCha8Rng;
use serde::Serialize;
use std::f64::consts::PI;

// ═══════════════════════════════════════════════════════
// CLI
// ═══════════════════════════════════════════════════════

#[derive(Parser, Debug)]
#[command(name = "hyperzeta-scan", about = "Headless HyperZeta morphology scanner")]
struct Args {
    /// Start of t sweep
    #[arg(long, default_value_t = 0.0)]
    t_start: f64,

    /// End of t sweep
    #[arg(long, default_value_t = 60.0)]
    t_end: f64,

    /// Step size for t
    #[arg(long, default_value_t = 0.005)]
    dt: f64,

    /// Number of particles
    #[arg(long, default_value_t = 25000)]
    particles: usize,

    /// Number of Dirichlet terms (Möbius sum depth)
    #[arg(long, default_value_t = 16)]
    terms: usize,

    /// Output interval: emit a record every N steps (1 = every step)
    #[arg(long, default_value_t = 20)]
    emit_every: usize,

    /// Number of PCA samples per frame
    #[arg(long, default_value_t = 5000)]
    pca_samples: usize,

    /// Output format: "jsonl" or "csv"
    #[arg(long, default_value = "jsonl")]
    format: String,

    /// Random seed for reproducible particle initialization (0 = random)
    #[arg(long, default_value_t = 42)]
    seed: u64,
}

// ═══════════════════════════════════════════════════════
// KNOWN ZETA ZEROS
// ═══════════════════════════════════════════════════════

const KNOWN_ZEROS: [f64; 30] = [
    14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
    37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
    52.970321, 56.446248, 59.347044, 60.831779, 65.112544,
    67.079811, 69.546402, 72.067158, 75.704691, 77.144840,
    79.337375, 82.910381, 84.735493, 87.425275, 88.809111,
    92.491899, 94.651344, 95.870634, 98.831194, 101.317851,
];

// ═══════════════════════════════════════════════════════
// MÖBIUS FUNCTION (extended to 64 terms)
// ═══════════════════════════════════════════════════════

fn moebius(n: u32) -> i32 {
    if n == 0 { return 0; }
    if n == 1 { return 1; }
    let mut remaining = n;
    let mut num_factors = 0u32;
    let mut d = 2u32;
    while d * d <= remaining {
        if remaining % d == 0 {
            remaining /= d;
            if remaining % d == 0 { return 0; } // squared factor
            num_factors += 1;
        }
        d += 1;
    }
    if remaining > 1 { num_factors += 1; }
    if num_factors % 2 == 0 { 1 } else { -1 }
}

// ═══════════════════════════════════════════════════════
// OUTPUT STRUCTURES
// ═══════════════════════════════════════════════════════

#[derive(Serialize)]
struct ScanRecord {
    t: f64,
    step: usize,
    terms: usize,             // Dirichlet series truncation depth
    collapse_metric: f64,
    zero_index: i32,          // which zero interval we're in (-1 = before first)
    dist_to_nearest_zero: f64,

    // Shape classification
    shape: String,
    shape_confidence: f64,
    eigenvalues: [f64; 3],
    flatness: f64,
    elongation: f64,
    ring_score: f64,
    void_score: f64,

    // Matter/antimatter
    matter_fraction: f64,     // fraction of particles with Re(Möbius sum) > 0
    antimatter_fraction: f64, // fraction with Re(Möbius sum) < 0
    net_sign: f64,            // mean sign (+1 = all matter, -1 = all antimatter)
    sign_variance: f64,       // variance of sign distribution

    // Jet detection
    jet_count: usize,
    jet_max_energy: f64,

    // Layer energies (Cayley-Dickson)
    energy_real: f64,
    energy_complex: f64,
    energy_quaternion: f64,
    energy_octonion: f64,
    energy_sedenion: f64,
}

// ═══════════════════════════════════════════════════════
// PCA EIGENVALUE SOLVER (Cardano's method)
// ═══════════════════════════════════════════════════════

fn eigenvalues_3x3(a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) -> [f64; 3] {
    let p1 = d * d + f * f + e * e;
    if p1 < 1e-12 {
        let mut vals = [a, b, c];
        vals.sort_by(|x, y| y.partial_cmp(x).unwrap());
        return vals;
    }
    let q = (a + b + c) / 3.0;
    let p2 = (a - q).powi(2) + (b - q).powi(2) + (c - q).powi(2) + 2.0 * p1;
    let p = (p2 / 6.0).sqrt();
    let ba = (a - q) / p;
    let bb = (b - q) / p;
    let bc = (c - q) / p;
    let bd = d / p;
    let be = e / p;
    let bf = f / p;
    let det_b = ba * (bb * bc - be * be) - bd * (bd * bc - be * bf) + bf * (bd * be - bb * bf);
    let r = (det_b / 2.0).clamp(-1.0, 1.0);
    let phi = r.acos() / 3.0;
    let e1 = q + 2.0 * p * phi.cos();
    let e3 = q + 2.0 * p * (phi + 2.0 * PI / 3.0).cos();
    let e2 = 3.0 * q - e1 - e3;
    let mut vals = [e1, e2, e3];
    vals.sort_by(|x, y| y.partial_cmp(x).unwrap());
    vals
}

// ═══════════════════════════════════════════════════════
// SHAPE CLASSIFICATION
// ═══════════════════════════════════════════════════════

fn classify_shape(
    positions: &[(f64, f64, f64)],
    pca_samples: usize,
) -> (String, f64, [f64; 3], f64, f64, f64, f64) {
    let n = positions.len();
    if n < 10 {
        return ("unknown".into(), 0.0, [0.0; 3], 1.0, 1.0, 0.0, 0.0);
    }

    let step = (n / pca_samples).max(1);
    let mut cx = 0.0f64;
    let mut cy = 0.0f64;
    let mut cz = 0.0f64;
    let mut count = 0usize;

    for i in (0..n).step_by(step) {
        let (x, y, z) = positions[i];
        cx += x; cy += y; cz += z;
        count += 1;
    }
    cx /= count as f64; cy /= count as f64; cz /= count as f64;

    // Covariance + radial + angular histograms
    let mut cxx = 0.0; let mut cyy = 0.0; let mut czz = 0.0;
    let mut cxy = 0.0; let mut cxz = 0.0; let mut cyz_v = 0.0;
    let radial_bins = 20usize;
    let angular_bins = 8usize;
    let mut radial_hist = vec![0.0f64; radial_bins];
    let mut angular_hist = vec![0.0f64; angular_bins];
    let mut max_r = 0.0f64;

    for i in (0..n).step_by(step) {
        let (x, y, z) = positions[i];
        let dx = x - cx; let dy = y - cy; let dz = z - cz;
        cxx += dx * dx; cyy += dy * dy; czz += dz * dz;
        cxy += dx * dy; cxz += dx * dz; cyz_v += dy * dz;
        let r = (dx * dx + dy * dy + dz * dz).sqrt();
        if r > max_r { max_r = r; }
    }
    let cf = count as f64;
    cxx /= cf; cyy /= cf; czz /= cf; cxy /= cf; cxz /= cf; cyz_v /= cf;

    if max_r > 0.01 {
        for i in (0..n).step_by(step) {
            let (x, y, z) = positions[i];
            let dx = x - cx; let dy = y - cy; let dz = z - cz;
            let r = (dx * dx + dy * dy + dz * dz).sqrt();
            let bin = ((r / max_r) * radial_bins as f64).min(radial_bins as f64 - 1.0) as usize;
            radial_hist[bin] += 1.0;
            let phi = dy.atan2(dx);
            let ai = (((phi + PI) / (2.0 * PI)) * angular_bins as f64) as usize % angular_bins;
            angular_hist[ai] += 1.0;
        }
    }

    let eigs = eigenvalues_3x3(cxx, cyy, czz, cxy, cyz_v, cxz);
    let safe_l3 = eigs[2].max(0.001);
    let safe_l2 = eigs[1].max(0.001);
    let flatness = eigs[0] / safe_l3;
    let elongation = eigs[0] / safe_l2;

    // Void score
    let inner_bins = (radial_bins as f64 * 0.25).max(1.0) as usize;
    let inner_count: f64 = radial_hist[..inner_bins].iter().sum();
    let outer_count: f64 = radial_hist[inner_bins..].iter().sum();
    let inner_frac = inner_count / (inner_count + outer_count + 1.0);
    let void_score = (1.0 - inner_frac / 0.016f64.max(0.001)).max(0.0);
    let is_hollow = void_score > 0.3 && inner_frac < 0.05;

    // Ring score
    let mut peak_bin = 0usize;
    let mut peak_val = 0.0f64;
    for i in 1..radial_bins {
        if radial_hist[i] > peak_val { peak_val = radial_hist[i]; peak_bin = i; }
    }
    let center_mass = radial_hist[0] + radial_hist.get(1).copied().unwrap_or(0.0);
    let ring_score = if peak_val > 0.0 {
        (peak_bin as f64 / radial_bins as f64) * (peak_val / (center_mass + 1.0))
    } else { 0.0 };

    // Angular contrast
    let ang_max = angular_hist.iter().cloned().fold(0.0f64, f64::max);
    let ang_min = angular_hist.iter().cloned().fold(f64::INFINITY, f64::min);
    let ang_total: f64 = angular_hist.iter().sum();
    let ang_avg = ang_total / angular_bins as f64;
    let ang_contrast = if ang_avg > 0.0 { (ang_max - ang_min) / ang_avg } else { 0.0 };
    let hot_sectors = angular_hist.iter().filter(|&&v| v > ang_avg * 1.3).count();

    // Classification
    let (shape, confidence) = if is_hollow && flatness < 3.0 && ring_score > 0.1 {
        ("torus", (void_score * 1.5).min(1.0))
    } else if (is_hollow && flatness > 2.0) || (ring_score > 0.3 && flatness > 2.0) {
        ("ring", ((void_score + ring_score) * 0.8).min(1.0))
    } else if ang_contrast > 1.5 && hot_sectors >= 2 && hot_sectors <= 4 && flatness < 3.0 {
        ("cross", (ang_contrast / 3.0).min(1.0))
    } else if elongation > 3.5 {
        ("line", (elongation / 8.0).min(1.0))
    } else if flatness > 3.0 && elongation < 2.5 && !is_hollow {
        ("disc", (flatness / 8.0).min(1.0))
    } else if flatness > 2.0 && elongation > 1.5 && ang_contrast > 0.8 {
        ("bipolar", ((flatness * elongation) / 12.0).min(1.0))
    } else {
        ("sphere", 1.0 - (flatness / 3.0).min(0.9))
    };

    (shape.to_string(), confidence, eigs, flatness, elongation, ring_score, void_score)
}

// ═══════════════════════════════════════════════════════
// JET DETECTION (angular binning)
// ═══════════════════════════════════════════════════════

fn detect_jets(positions: &[(f64, f64, f64)], cx: f64, cy: f64, cz: f64) -> (usize, f64) {
    let phi_bins = 12usize;
    let theta_bins = 6usize;
    let total = phi_bins * theta_bins;
    let mut bins = vec![0.0f64; total];
    let mut energy_bins = vec![0.0f64; total];

    for &(x, y, z) in positions.iter() {
        let dx = x - cx; let dy = y - cy; let dz = z - cz;
        let r = (dx * dx + dy * dy + dz * dz).sqrt();
        if r < 0.01 { continue; }
        let phi = dy.atan2(dx);
        let theta = (dz / r).acos();
        let pi = ((phi + PI) / (2.0 * PI) * phi_bins as f64) as usize % phi_bins;
        let ti = ((theta / PI) * theta_bins as f64).min(theta_bins as f64 - 1.0) as usize;
        let idx = ti * phi_bins + pi;
        bins[idx] += 1.0;
        energy_bins[idx] += r * r;
    }

    let avg: f64 = bins.iter().sum::<f64>() / total as f64;
    let threshold = avg * 3.0;
    let mut jet_count = 0;
    let mut max_energy = 0.0f64;
    for i in 0..total {
        if bins[i] > threshold {
            jet_count += 1;
            if energy_bins[i] > max_energy { max_energy = energy_bins[i]; }
        }
    }
    (jet_count, max_energy)
}

// ═══════════════════════════════════════════════════════
// MAIN SWEEP ENGINE
// ═══════════════════════════════════════════════════════

fn main() {
    let args = Args::parse();

    eprintln!("╔══════════════════════════════════════════════════════════╗");
    eprintln!("║  HYPERZETA MORPHOLOGY SCANNER                          ║");
    eprintln!("║  Headless Cayley-Dickson Tower Analysis                 ║");
    eprintln!("╚══════════════════════════════════════════════════════════╝");
    eprintln!();
    eprintln!("  particles:  {}", args.particles);
    eprintln!("  terms:      {}", args.terms);
    eprintln!("  seed:       {}", args.seed);
    eprintln!("  t range:    {} → {} (dt={})", args.t_start, args.t_end, args.dt);
    eprintln!("  emit every: {} steps", args.emit_every);
    eprintln!("  PCA samples: {}", args.pca_samples);
    eprintln!("  format:     {}", args.format);
    eprintln!();

    // Initialize particles with deterministic seed for reproducibility
    let mut rng = if args.seed == 0 {
        ChaCha8Rng::from_entropy()
    } else {
        ChaCha8Rng::seed_from_u64(args.seed)
    };
    let mut particles: Vec<Sedenion> = (0..args.particles)
        .map(|_| {
            let q1 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            let q2 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            let q3 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            let q4 = Quaternion::new(
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
                rng.gen_range(-1.0..1.0), rng.gen_range(-1.0..1.0),
            );
            Sedenion::new(Octonion::new(q1, q2), Octonion::new(q3, q4)).normalize()
        })
        .collect();

    // Skip to t_start
    let skip_steps = (args.t_start / args.dt) as usize;
    let total_steps = ((args.t_end - args.t_start) / args.dt) as usize;

    if args.format == "csv" {
        println!("t,step,collapse_metric,zero_index,dist_to_nearest_zero,\
                  shape,shape_confidence,eig1,eig2,eig3,flatness,elongation,\
                  ring_score,void_score,matter_fraction,antimatter_fraction,\
                  net_sign,sign_variance,jet_count,jet_max_energy,\
                  energy_real,energy_complex,energy_quaternion,energy_octonion,energy_sedenion");
    }

    let vm = 40.0;
    let terms = args.terms;

    for global_step in 0..(skip_steps + total_steps) {
        let lambda = (global_step as f64) * args.dt;

        // Background rotator (same as WASM engine)
        let rot_quat1 = Quaternion::new(lambda.cos(), lambda.sin(), (lambda * 0.1).cos(), 0.0);
        let rot_quat2 = Quaternion::new(0.0, (lambda * 0.2).sin(), 0.0, 1.0);
        let rot_oct = Octonion::new(rot_quat1, rot_quat2);
        let active_rotator = Sedenion::new(rot_oct, rot_oct.conjugate()).normalize();

        // Per-particle physics
        let mut positions: Vec<(f64, f64, f64)> = Vec::with_capacity(args.particles);
        let mut signs: Vec<f64> = Vec::with_capacity(args.particles);
        let mut total_magnitude = 0.0f64;
        let mut layer_e = [0.0f64; 5];
        let mut matter_count = 0usize;
        let mut antimatter_count = 0usize;
        let mut sign_sum = 0.0f64;
        let mut sign_sq_sum = 0.0f64;

        for i in 0..args.particles {
            particles[i] = particles[i].mul(&active_rotator).normalize();
            let mut s_coord = particles[i].scale(10.0 + lambda * 2.0);
            s_coord.a.a.r = 0.5; // CRITICAL LINE

            // Compute 1/ζ(s) = Σ μ(n)/n^s
            let mut mobius_sum = Sedenion::zero();
            for n in 1..=terms {
                let mu = moebius(n as u32);
                if mu == 0 { continue; }
                let ln_n = (n as f64).ln();
                let neg_s_ln_n = s_coord.scale(-ln_n);
                let dirichlet_term = neg_s_ln_n.exp();
                if mu == 1 {
                    mobius_sum = mobius_sum.add(&dirichlet_term);
                } else {
                    mobius_sum = mobius_sum.sub(&dirichlet_term);
                }
            }

            let oq = mobius_sum.a.a;
            total_magnitude += oq.norm_sq();

            let x = oq.i * vm;
            let y = oq.j * vm;
            let z = oq.k * vm;
            positions.push((x, y, z));

            // Matter/antimatter sign
            let real_part = mobius_sum.a.a.r;
            let sign = if real_part > 0.0 { 1.0 } else { -1.0 };
            signs.push(sign);
            if sign > 0.0 { matter_count += 1; } else { antimatter_count += 1; }
            sign_sum += sign;
            sign_sq_sum += 1.0; // sign² = 1 always

            // Layer energies
            let e_real = mobius_sum.a.a.r * mobius_sum.a.a.r;
            let e_complex = mobius_sum.a.a.i * mobius_sum.a.a.i;
            let e_quat = mobius_sum.a.a.j * mobius_sum.a.a.j + mobius_sum.a.a.k * mobius_sum.a.a.k;
            let e_oct = mobius_sum.a.b.norm_sq();
            let e_sed = mobius_sum.b.norm_sq();
            layer_e[0] += e_real;
            layer_e[1] += e_complex;
            layer_e[2] += e_quat;
            layer_e[3] += e_oct;
            layer_e[4] += e_sed;
        }

        // Skip output during warmup phase
        if global_step < skip_steps { continue; }
        let local_step = global_step - skip_steps;
        if local_step % args.emit_every != 0 { continue; }

        let n = args.particles as f64;
        let collapse = total_magnitude / n;
        let net_sign = sign_sum / n;
        let sign_var = (sign_sq_sum / n) - (net_sign * net_sign); // Var(sign)

        // Centroid for jet detection
        let cx: f64 = positions.iter().map(|p| p.0).sum::<f64>() / n;
        let cy: f64 = positions.iter().map(|p| p.1).sum::<f64>() / n;
        let cz: f64 = positions.iter().map(|p| p.2).sum::<f64>() / n;

        // Shape classification
        let (shape, confidence, eigs, flatness, elongation, ring_score, void_score) =
            classify_shape(&positions, args.pca_samples);

        // Jet detection
        let (jet_count, jet_max_energy) = detect_jets(&positions, cx, cy, cz);

        // Zero proximity
        let mut dist_to_nearest = f64::INFINITY;
        let mut zero_idx: i32 = -1;
        for (zi, &z) in KNOWN_ZEROS.iter().enumerate() {
            let d = (lambda - z).abs();
            if d < dist_to_nearest { dist_to_nearest = d; }
            if lambda >= z { zero_idx = zi as i32; }
        }

        let record = ScanRecord {
            t: lambda,
            step: local_step,
            terms,
            collapse_metric: collapse,
            zero_index: zero_idx,
            dist_to_nearest_zero: dist_to_nearest,
            shape,
            shape_confidence: confidence,
            eigenvalues: eigs,
            flatness,
            elongation,
            ring_score,
            void_score,
            matter_fraction: matter_count as f64 / n,
            antimatter_fraction: antimatter_count as f64 / n,
            net_sign,
            sign_variance: sign_var,
            jet_count,
            jet_max_energy,
            energy_real: layer_e[0] / n,
            energy_complex: layer_e[1] / n,
            energy_quaternion: layer_e[2] / n,
            energy_octonion: layer_e[3] / n,
            energy_sedenion: layer_e[4] / n,
        };

        if args.format == "csv" {
            println!("{:.6},{},{:.8},{},{:.6},{},{:.4},{:.6},{:.6},{:.6},{:.3},{:.3},{:.4},{:.4},{:.4},{:.4},{:.6},{:.6},{},{:.4},{:.8},{:.8},{:.8},{:.8},{:.8}",
                record.t, record.step, record.collapse_metric,
                record.zero_index, record.dist_to_nearest_zero,
                record.shape, record.shape_confidence,
                record.eigenvalues[0], record.eigenvalues[1], record.eigenvalues[2],
                record.flatness, record.elongation, record.ring_score, record.void_score,
                record.matter_fraction, record.antimatter_fraction,
                record.net_sign, record.sign_variance,
                record.jet_count, record.jet_max_energy,
                record.energy_real, record.energy_complex,
                record.energy_quaternion, record.energy_octonion, record.energy_sedenion);
        } else {
            println!("{}", serde_json::to_string(&record).unwrap());
        }

        // Progress to stderr
        if local_step % (args.emit_every * 50) == 0 {
            eprintln!("  t={:.3}  shape={:<8} matter={:.1}%  jets={}  collapse={:.4}",
                lambda, record.shape, record.matter_fraction * 100.0,
                jet_count, collapse);
        }
    }

    eprintln!("\n  Scan complete. {} records emitted.", total_steps / args.emit_every);
}
