//! Output writers for the Möbius Cancellation Microscope v3.
//! Produces summary, GCD decomp, trace, certificate, dyadic, ω-class, and taper files.

use crate::decomp::Decomp;
use cathedral_utils::arith;
use std::io::Write;

const EULER_GAMMA: f64 = arith::EULER_GAMMA;

pub fn write_summary(d: &Decomp, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/summary_N{}.txt", d.n);
    let mut f = std::fs::File::create(&p)?;
    let tot = d.total.value();
    let ta = tot.abs().max(1e-30);

    writeln!(
        f,
        "═══ MÖBIUS CANCELLATION MICROSCOPE v3 — N={} ═══\nDim: {}\n",
        d.n, d.dim
    )?;

    writeln!(f, "QUADRATIC FORM vᵀGv")?;
    writeln!(f, "  Total:        {tot:.15e}")?;
    writeln!(f, "  Diagonal:     {:.15e}", d.diagonal.value())?;
    writeln!(f, "  Off-diagonal: {:.15e}", d.off_diagonal.value())?;
    writeln!(
        f,
        "  |off|/|diag|: {:.6}\n",
        d.off_diagonal.value().abs() / d.diagonal.value().abs().max(1e-30)
    )?;

    let chk = d.diagonal.value() + d.off_diagonal.value();
    writeln!(
        f,
        "SANITY: diag+off={chk:.15e}  err={:.2e}\n",
        (chk - tot).abs()
    )?;

    let (t1, t2, t3) = (d.type_i.value(), d.type_ii.value(), d.type_iii.value());
    writeln!(f, "VAUGHAN TYPE DECOMPOSITION")?;
    writeln!(
        f,
        "  I  (min≤N^1/3):   {t1:.15e}  ({:.2}%)",
        100.0 * t1.abs() / ta
    )?;
    writeln!(
        f,
        "  II (mid range):   {t2:.15e}  ({:.2}%)",
        100.0 * t2.abs() / ta
    )?;
    writeln!(
        f,
        "  III(min>N^2/3):   {t3:.15e}  ({:.2}%)",
        100.0 * t3.abs() / ta
    )?;
    writeln!(f, "  Sum check err: {:.2e}\n", (t1 + t2 + t3 - tot).abs())?;

    let (ee, eo, oe, oo) = (d.ee.value(), d.eo.value(), d.oe.value(), d.oo.value());
    let (same, cross) = (ee + oo, eo + oe);
    writeln!(f, "LIOUVILLE PARITY")?;
    writeln!(f, "  (+,+): {ee:.15e}  (+,-): {eo:.15e}")?;
    writeln!(f, "  (-,+): {oe:.15e}  (-,-): {oo:.15e}")?;
    writeln!(f, "  Same:  {same:.15e}  Cross: {cross:.15e}")?;
    writeln!(
        f,
        "  Cancel ratio: {:.6}\n",
        (same + cross).abs() / (same.abs() + cross.abs()).max(1e-30)
    )?;

    writeln!(f, "ROTOR CHANNELS (mod-8)")?;
    for ch in 0..4 {
        writeln!(f, "  χ_{ch}: {:.15e}", d.channels[ch].value())?;
    }
    writeln!(f)?;

    writeln!(f, "ω-CLASS MATRIX (rows=ω(j), cols=ω(k))")?;
    let mo = d.max_omega.min(5);
    write!(f, "     ")?;
    for wk in 0..=mo {
        write!(f, "  ω={wk:>8}")?;
    }
    writeln!(f)?;
    for wj in 0..=mo {
        write!(f, "ω={wj} ")?;
        for wk in 0..=mo {
            write!(f, " {:>11.4e}", d.omega_buckets[wj][wk].value())?;
        }
        writeln!(f)?;
    }
    writeln!(f)?;

    writeln!(f, "DYADIC SCALE BANDS (rows=⌊log₂j⌋, cols=⌊log₂k⌋)")?;
    write!(f, "     ")?;
    for bk in 1..=d.max_band {
        write!(f, " [{:>4},{:>5})", 1 << bk, 1 << (bk + 1))?;
    }
    writeln!(f)?;
    for bj in 1..=d.max_band {
        write!(f, "[{:>3},{})", 1 << bj, 1 << (bj + 1))?;
        for bk in 1..=d.max_band {
            let v = d.dyadic[bj][bk].value();
            if v.abs() > 1e-30 {
                write!(f, " {:>12.4e}", v)?;
            } else {
                write!(f, " {:>12}", "—")?;
            }
        }
        writeln!(f)?;
    }
    writeln!(f)?;

    let total_terms = d.n_pos + d.n_neg;
    let (sp, sn) = (d.sum_pos.value(), d.sum_neg.value());
    writeln!(f, "SIGN STATISTICS")?;
    writeln!(
        f,
        "  Positive: {} ({:.1}%)  sum={sp:.8e}",
        d.n_pos,
        100.0 * d.n_pos as f64 / total_terms.max(1) as f64
    )?;
    writeln!(
        f,
        "  Negative: {} ({:.1}%)  sum={sn:.8e}",
        d.n_neg,
        100.0 * d.n_neg as f64 / total_terms.max(1) as f64
    )?;
    writeln!(
        f,
        "  |Σ|/Σ|·| = {:.8}",
        tot.abs() / (sp + sn.abs()).max(1e-30)
    )?;
    writeln!(
        f,
        "  Cancellation power: {:.2}x\n",
        (sp + sn.abs()) / tot.abs().max(1e-30)
    )?;

    writeln!(f, "ROBIN σ(d)/d CORRELATION")?;
    writeln!(f, "  d\tQ_d\t\t\tσ(d)/d\te^γ·ln(ln(d))\tmargin")?;
    for dd in 1..=d.max_gcd.min(30) {
        let q = d.gcd_buckets[dd].value();
        if q.abs() < 1e-30 {
            continue;
        }
        let sig = d.robin_sigma[dd];
        let rb = if dd >= 3 {
            EULER_GAMMA.exp() * (dd as f64).ln().ln()
        } else {
            f64::INFINITY
        };
        writeln!(f, "  {dd}\t{q:.8e}\t{sig:.6}\t{rb:.6}\t{:+.6}", rb - sig)?;
    }

    writeln!(f, "\nGRAM BOUND AXIOM ANALYSIS")?;
    writeln!(f, "  vᵀGv        = {:.15e}", d.total.value())?;
    writeln!(f, "  (bᵀv)²      = {:.15e}", d.gram.btv_sq)?;
    writeln!(f, "  bᵀv         = {:.15e}", d.gram.btv)?;
    writeln!(f, "  vᵀCv        = {:.15e}", d.gram.vtcv)?;
    writeln!(f, "  d²_N        = {:.15e}", d.gram.d2n)?;
    writeln!(f, "  1 - vᵀGv    = {:.15e}", d.gram.gap)?;
    writeln!(f, "  gap·ln(N)   = {:.15e}", d.gram.gap_times_ln)?;
    writeln!(f, "  (bᵀv)²/vᵀGv = {:.15e}", d.gram.ratio)?;
    writeln!(
        f,
        "  vtCv·ln(N)  = {:.15e}",
        d.gram.vtcv * (d.n as f64).ln()
    )?;
    writeln!(f, "  d²·ln(N)    = {:.15e}", d.gram.d2n * (d.n as f64).ln())?;
    writeln!(f, "  Precision   = {}", d.precision)?;
    writeln!(
        f,
        "  Axiom sat?  = {} (vtGv < 1 + K/ln(N) for any K > 0)",
        if d.total.value() < 1.0 {
            "YES"
        } else {
            "CHECK"
        }
    )?;

    // §5 Taper Cancellation
    let t = &d.taper;
    let ln_n = (d.n as f64).ln();
    writeln!(f, "\nTAPER CANCELLATION TRACKER")?;
    writeln!(f, "  U(N)           = {:.15e}", t.u_sum.value())?;
    writeln!(f, "  L(N)           = {:.15e}", t.l_sum.value())?;
    writeln!(f, "  Q(N)           = {:.15e}", t.q_sum.value())?;
    writeln!(f, "  R₂ = U-2L/lnN  = {:.15e}", t.r2)?;
    writeln!(f, "  R₂ - 1         = {:.15e}", t.r2_minus_1)?;
    writeln!(f, "  (R₂-1)·lnN     = {:.15e}  (→ const?)", t.r2_times_ln)?;
    writeln!(f, "  Q/ln²N         = {:.15e}", t.q_over_ln2)?;
    writeln!(f, "  C_recon         = {:.15e}  (≈ 2.87?)", t.c_recon)?;
    writeln!(f, "  S₁ = Σμ/k      = {:.15e}  (→ 0)", t.s1)?;
    writeln!(f, "  S₂ = Σμlnk/k   = {:.15e}  (→ -1)", t.s2)?;
    writeln!(f, "  S₃ = Σμln²k/k  = {:.15e}  (→ -2γ)", t.s3)?;
    writeln!(f, "  M(N)           = {:.0}", t.mertens)?;
    writeln!(f, "  M(N)/√N        = {:.15e}", t.mertens_over_sqrt)?;
    let recon = t.u_sum.value() - 2.0 / ln_n * t.l_sum.value() + t.q_sum.value() / (ln_n * ln_n);
    writeln!(f, "  Recon check    = {:.15e}  (should = vᵀGv)", recon)?;
    writeln!(
        f,
        "  Δ              = {:.2e}",
        (recon - d.total.value()).abs()
    )?;

    eprintln!("  ✓ Summary → {p}");
    Ok(())
}

pub fn write_gcd(d: &Decomp, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/gcd_decomp_N{}.tsv", d.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(f, "d\tQ_d\tabs_Q_d\tcumul_pct\tsigma_d\tfactorization")?;
    let ta = d.total.value().abs().max(1e-30);
    let mut cum = 0.0;
    for dd in 1..=d.max_gcd {
        let q = d.gcd_buckets[dd].value();
        if q.abs() < 1e-30 {
            continue;
        }
        cum += q.abs();
        writeln!(
            f,
            "{dd}\t{q:.15e}\t{:.15e}\t{:.4}\t{:.6}\t{}",
            q.abs(),
            100.0 * cum / ta,
            d.robin_sigma[dd],
            arith::factorize(dd)
        )?;
    }
    eprintln!("  ✓ GCD → {p}");
    Ok(())
}

pub fn write_trace(d: &Decomp, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/trace_N{}.tsv", d.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(f, "M\tS_M\tsum_abs\tcancel_ratio\tln_M")?;
    for pt in &d.trace {
        let r = if pt.running_abs > 0.0 {
            pt.running_sum.abs() / pt.running_abs
        } else {
            0.0
        };
        writeln!(
            f,
            "{}\t{:.15e}\t{:.15e}\t{r:.8}\t{:.6}",
            pt.j,
            pt.running_sum,
            pt.running_abs,
            (pt.j as f64).ln()
        )?;
    }
    eprintln!("  ✓ Trace → {p}");
    Ok(())
}

pub fn write_cert(d: &Decomp, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/certificate_N{}.json", d.n);
    let gcd_top: Vec<serde_json::Value> = (1..=d.max_gcd)
        .filter(|&dd| d.gcd_buckets[dd].value().abs() > 1e-30)
        .take(30)
        .map(|dd| serde_json::json!({"d": dd, "Q_d": d.gcd_buckets[dd].value(), "sigma_d": d.robin_sigma[dd]}))
        .collect();

    let mut omega_data = Vec::new();
    for wj in 0..=d.max_omega.min(5) {
        for wk in 0..=d.max_omega.min(5) {
            let v = d.omega_buckets[wj][wk].value();
            if v.abs() > 1e-30 {
                omega_data.push(serde_json::json!({"wj": wj, "wk": wk, "Q": v}));
            }
        }
    }

    let t = &d.taper;
    let ln_n = (d.n as f64).ln();
    let gcd_taper_strata: Vec<serde_json::Value> = (1..=d.max_gcd)
        .filter(|&dd| {
            d.taper.u_by_gcd[dd].value().abs() > 1e-15 || d.taper.l_by_gcd[dd].value().abs() > 1e-15
        })
        .take(50)
        .map(|dd| {
            let u_d = d.taper.u_by_gcd[dd].value();
            let l_d = d.taper.l_by_gcd[dd].value();
            let q_d = d.taper.q_by_gcd[dd].value();
            let r2_d = u_d - 2.0 * l_d / ln_n;
            serde_json::json!({"d": dd, "U_d": u_d, "L_d": l_d, "Q_d": q_d, "R2_d": r2_d})
        })
        .collect();

    let cert = serde_json::json!({
        "experiment": "moebius-microscope", "version": "3.1", "N": d.n, "dim": d.dim,
        "precision": d.precision,
        "quadratic_form": {"total": d.total.value(), "diagonal": d.diagonal.value(), "off_diagonal": d.off_diagonal.value()},
        "gram_bound": {
            "vtGv": d.total.value(),
            "btv": d.gram.btv,
            "btv_sq": d.gram.btv_sq,
            "vtCv": d.gram.vtcv,
            "d2N": d.gram.d2n,
            "ratio_btv2_vtGv": d.gram.ratio,
            "gap_1_minus_vtGv": d.gram.gap,
            "gap_times_lnN": d.gram.gap_times_ln,
            "vtCv_times_lnN": d.gram.vtcv * (d.n as f64).ln(),
            "d2_times_lnN": d.gram.d2n * (d.n as f64).ln(),
        },
        "taper_cancellation": {
            "U": t.u_sum.value(),
            "L": t.l_sum.value(),
            "Q": t.q_sum.value(),
            "R2": t.r2,
            "R2_minus_1": t.r2_minus_1,
            "R2_minus_1_times_lnN": t.r2_times_ln,
            "Q_over_ln2N": t.q_over_ln2,
            "C_recon": t.c_recon,
            "S1": t.s1,
            "S2": t.s2,
            "S3": t.s3,
            "mertens": t.mertens,
            "mertens_over_sqrt": t.mertens_over_sqrt,
        },
        "gcd_taper_strata": gcd_taper_strata,
        "vaughan": {"type_I": d.type_i.value(), "type_II": d.type_ii.value(), "type_III": d.type_iii.value()},
        "liouville": {"ee": d.ee.value(), "eo": d.eo.value(), "oe": d.oe.value(), "oo": d.oo.value(),
            "same": d.ee.value()+d.oo.value(), "cross": d.eo.value()+d.oe.value()},
        "rotors": {"chi0": d.channels[0].value(), "chi1": d.channels[1].value(),
            "chi2": d.channels[2].value(), "chi3": d.channels[3].value()},
        "sign_stats": {"n_pos": d.n_pos, "n_neg": d.n_neg, "sum_pos": d.sum_pos.value(), "sum_neg": d.sum_neg.value(),
            "cancel_ratio": d.total.value().abs() / (d.sum_pos.value()+d.sum_neg.value().abs()).max(1e-30)},
        "gcd_top": gcd_top, "omega_class": omega_data,
    });

    let mut f = std::fs::File::create(&p)?;
    writeln!(f, "{}", serde_json::to_string_pretty(&cert).unwrap())?;
    eprintln!("  ✓ Cert → {p}");
    Ok(())
}

pub fn write_dyadic(d: &Decomp, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/dyadic_N{}.tsv", d.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(f, "band_j\tband_k\trange_j\trange_k\tQ_band")?;
    for bj in 1..=d.max_band {
        for bk in 1..=d.max_band {
            let v = d.dyadic[bj][bk].value();
            if v.abs() > 1e-30 {
                writeln!(
                    f,
                    "{bj}\t{bk}\t[{},{})\t[{},{})\t{v:.15e}",
                    1 << bj,
                    1 << (bj + 1),
                    1 << bk,
                    1 << (bk + 1)
                )?;
            }
        }
    }
    eprintln!("  ✓ Dyadic → {p}");
    Ok(())
}

pub fn write_omega(d: &Decomp, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/omega_class_N{}.tsv", d.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(f, "omega_j\tomega_k\tQ_value")?;
    for wj in 0..=d.max_omega.min(6) {
        for wk in 0..=d.max_omega.min(6) {
            let v = d.omega_buckets[wj][wk].value();
            if v.abs() > 1e-30 {
                writeln!(f, "{wj}\t{wk}\t{v:.15e}")?;
            }
        }
    }
    eprintln!("  ✓ ω-class → {p}");
    Ok(())
}

/// Write all output files for a decomposition.
pub fn write_all(d: &Decomp, dir: &str) -> std::io::Result<()> {
    write_summary(d, dir)?;
    write_gcd(d, dir)?;
    write_trace(d, dir)?;
    write_cert(d, dir)?;
    write_dyadic(d, dir)?;
    write_omega(d, dir)?;
    Ok(())
}
