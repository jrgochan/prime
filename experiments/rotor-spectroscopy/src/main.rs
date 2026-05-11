//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL ROTOR SPECTROSCOPY
//!  f64 · Massively Parallel · Certified Results
//!
//!  Validates the mod-8 character energy partition (Stained Glass Rotors),
//!  Gallagher MVT completeness relation, and log-frequency dispersion.
//!
//!  §A. SIEVE VALIDATION — μ(k) correctness + squarefree statistics
//!  §B. CHARACTER TABLE — χ₁..χ₄ mod 8, orthogonality verification
//!  §C. ENERGY PARTITION — per-channel energy fractions vs N
//!  §D. RESIDUE CLASS DECOMPOSITION — v_k² by k mod 8
//!  §E. SPECTRAL PROFILE — |D_N(1/2+it)|² per-channel on critical line
//!  §F. GALLAGHER MVT — ∫|D_N|²·K_δ vs Σ|v_k|²
//!  §G. DISPERSION RELATION — min |λ_j - λ_k| vs 1/(N+1)
//!  §H. SCALING LAW — channel fractions vs N (equipartition test)
//!
//!  Target: Validate `discrete_energy_partition` (GallagherPartition.lean)
//! ═══════════════════════════════════════════════════════════════════════════

// mod sieve; — replaced by cathedral-utils
pub mod characters;
mod weights;
mod spectral;

use cathedral_utils::fmt::*;
use std::fs;
use std::io::Write;
use std::time::Instant;

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args().nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(10_000);

    header(
        "CATHEDRAL ROTOR SPECTROSCOPY",
        &format!("Stained Glass Rotors · mod-8 character partition · max N = {max_n}"),
        weights::P, threads,
    );

    fs::create_dir_all("results").unwrap();

    let mut test_ns: Vec<usize> = vec![10, 50, 100, 500, 1000, 2000, 5000, 10_000];
    test_ns.retain(|&n| n <= max_n);
    if !test_ns.contains(&max_n) && max_n > 10 { test_ns.push(max_n); }
    test_ns.sort();
    test_ns.dedup();
    let sieve_max = *test_ns.last().unwrap();

    eprintln!("  {DIM}▸ Sieving μ(k) for k ≤ {sieve_max}...{RESET}");
    let mu = cathedral_utils::arith::mobius_table(sieve_max);
    let sqfree = mu[1..].iter().filter(|&&m| m != 0).count();
    eprintln!("  {GREEN}✓{RESET} Sieve complete ({sqfree} squarefree out of {sieve_max})");
    println!();

    // ═══ §A. SIEVE VALIDATION ═══
    println!("  {BOLD}{WHITE}═══ §A. SIEVE VALIDATION ═══{RESET}");
    println!();
    let test_vals = [(1, 1i8), (2, -1), (3, -1), (4, 0), (5, -1),
                     (6, 1), (7, -1), (8, 0), (12, 0), (30, -1)];
    println!("    {DIM}     k │ μ(k) │ expected │ ok{RESET}");
    let mut sieve_ok = true;
    for (k, expected) in test_vals {
        if k <= sieve_max {
            let ok = mu[k] == expected;
            sieve_ok &= ok;
            println!("    {:>5} │ {:>4} │ {:>8} │ {}", k, mu[k], expected, check(ok));
        }
    }
    println!();
    println!("    {} Sieve validated at {} test points", check(sieve_ok), test_vals.len());
    println!();

    // ═══ §B. CHARACTER TABLE ═══
    println!("  {BOLD}{WHITE}═══ §B. CHARACTER TABLE — Dirichlet characters mod 8 ═══{RESET}");
    println!();
    println!("    {DIM}k mod 8 │  χ₁  │  χ₂  │  χ₃  │  χ₄{RESET}");
    for r in 0..8 {
        println!("    {:>7} │ {:>4} │ {:>4} │ {:>4} │ {:>4}",
            r, characters::CHI_TABLE[0][r], characters::CHI_TABLE[1][r],
            characters::CHI_TABLE[2][r], characters::CHI_TABLE[3][r]);
    }
    println!();

    let orth = characters::verify_orthogonality();
    let mut orth_ok = true;
    println!("    {DIM}Orthogonality Σ χ_i(k)·χ_j(k):{RESET}");
    println!("    {DIM}  i │ j │ sum │ expected │ ok{RESET}");
    for (i, j, sum, ok) in &orth {
        let exp = if i == j { 4 } else { 0 };
        orth_ok &= ok;
        println!("    {:>3} │{:>2} │ {:>3} │ {:>8} │ {}", i, j, sum, exp, check(*ok));
    }
    println!();
    println!("    {} Character orthogonality verified (16/16 entries)", check(orth_ok));
    println!();

    // ═══ §C. ENERGY PARTITION ═══
    println!("  {BOLD}{WHITE}═══ §C. ENERGY PARTITION — (1/φ(8))·Σ E_i = Σ_{{gcd(k,8)=1}} |v_k|² ═══{RESET}");
    println!("  {DIM}  Characters vanish on even k → partition acts on odd sector only{RESET}");
    println!("  {DIM}  discrete_energy_partition (GallagherPartition.lean){RESET}");
    println!();

    let mut tsv_c = fs::File::create("results/energy_partition.tsv").unwrap();
    writeln!(tsv_c, "N\ttotal\todd\teven\tE1\tE2\tE3\tE4\tpartition_sum\tf64_err\tmpfr_err").unwrap();

    println!("    {DIM}     N │  total  │   odd   │  even  │  f(χ₁)  │  f(χ₂)  │  f(χ₃)  │  f(χ₄)  │ f64 err   │ 512-bit err{RESET}");
    let mut partition_results = Vec::new();
    for &n in &test_ns {
        let v = weights::bd_weights(n, &mu);
        let v_mp = weights::bd_weights_mpfr(n, &mu);
        let b = characters::channel_breakdown(n, &v, &v_mp);
        let ok = b.mpfr_partition_error < 1e-100;
        println!("    {:>5} │{:>8.2} │{:>8.2} │{:>7.2} │ {:>7.4} │ {:>7.4} │ {:>7.4} │ {:>7.4} │ {:.1e} │ {:.1e} {}",
            n, b.total_energy, b.odd_energy, b.even_energy,
            b.channel_fraction[0], b.channel_fraction[1],
            b.channel_fraction[2], b.channel_fraction[3],
            b.partition_error, b.mpfr_partition_error, check(ok));
        writeln!(tsv_c, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            n, b.total_energy, b.odd_energy, b.even_energy,
            b.channel_energy[0], b.channel_energy[1],
            b.channel_energy[2], b.channel_energy[3],
            b.partition_sum, b.partition_error, b.mpfr_partition_error).unwrap();
        partition_results.push(b);
    }
    println!();

    // ═══ §D. RESIDUE CLASS DECOMPOSITION ═══
    println!("  {BOLD}{WHITE}═══ §D. RESIDUE CLASS DECOMPOSITION — v_k² by k mod 8 ═══{RESET}");
    println!();
    let last_n = *test_ns.last().unwrap();
    let v_last = weights::bd_weights(last_n, &mu);
    let rs = weights::residue_class_stats(last_n, &v_last);

    let mut tsv_d = fs::File::create("results/residue_classes.tsv").unwrap();
    writeln!(tsv_d, "residue\tenergy\tcount\tfraction").unwrap();

    println!("    {DIM}N = {last_n}{RESET}");
    println!("    {DIM}k mod 8 │   energy   │ count │ fraction{RESET}");
    for r in 0..8 {
        let label = match r { 1 => " (all channels)", 3 | 5 | 7 => " (odd prime)", _ => " (dark)" };
        println!("    {:>7} │ {:>10.4} │ {:>5} │ {:>7.4}  {DIM}{label}{RESET}",
            r, rs.class_energy[r], rs.class_count[r], rs.class_fraction[r]);
        writeln!(tsv_d, "{}\t{:.15e}\t{}\t{:.15e}",
            r, rs.class_energy[r], rs.class_count[r], rs.class_fraction[r]).unwrap();
    }
    println!();

    // ═══ §E. SPECTRAL PROFILE ═══
    println!("  {BOLD}{WHITE}═══ §E. SPECTRAL PROFILE — |D_N(1/2+it)|² per channel ═══{RESET}");
    println!();

    // Compute MPFR weights for certified spectral profile
    let v_mpfr = weights::bd_weights_mpfr(last_n, &mu);
    let t_profile: Vec<f64> = (1..=15).map(|i| i as f64 * 5.0).collect();
    let profile = spectral::spectral_profile_mpfr(&v_mpfr, &t_profile);

    let mut tsv_e = fs::File::create("results/spectral_profile.tsv").unwrap();
    writeln!(tsv_e, "t\ttotal\tch1\tch2\tch3\tch4").unwrap();

    println!("    {DIM}N = {last_n}{RESET}");
    println!("    {DIM}      t │  |D_N|²  │  ch1     │  ch2     │  ch3     │  ch4{RESET}");
    for (t, total, ch) in &profile {
        println!("    {:>7.1} │ {:>8.4} │ {:>8.4} │ {:>8.4} │ {:>8.4} │ {:>8.4}",
            t, total, ch[0], ch[1], ch[2], ch[3]);
        writeln!(tsv_e, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
            t, total, ch[0], ch[1], ch[2], ch[3]).unwrap();
    }
    println!();

    // ═══ §F. GALLAGHER MVT ═══
    println!("  {BOLD}{WHITE}═══ §F. GALLAGHER MVT — ∫|D_N|²·K_δ = Σ|v_k|² ═══{RESET}");
    println!("  {DIM}  Completeness relation (GallagherMVT.lean){RESET}");
    println!();

    let mut tsv_f = fs::File::create("results/gallagher_mvt.tsv").unwrap();
    writeln!(tsv_f, "N\tsum_vk_sq\tintegral\trelative_error").unwrap();

    // Use smaller N values for Gallagher (expensive integral)
    let gallagher_ns: Vec<usize> = test_ns.iter().copied().filter(|&n| n <= 2000).collect();
    println!("    {DIM}     N │   Σ|v_k|²  │  ∫|D|²·K_δ │ rel error{RESET}");
    for &n in &gallagher_ns {
        let v = weights::bd_weights(n, &mu);
        let t = Instant::now();
        let t_max_g = (n as f64 * 2.0).min(500.0);
        let g = spectral::gallagher_validate(n, &v, t_max_g);
        let el = t.elapsed().as_secs_f64();
        let ok = g.relative_error < 0.1;
        println!("    {:>5} │ {:>10.4} │ {:>10.4}  │ {:.4e} {} ({})",
            n, g.sum_vk_sq, g.integral, g.relative_error, check(ok), elapsed(el));
        writeln!(tsv_f, "{}\t{:.15e}\t{:.15e}\t{:.15e}",
            n, g.sum_vk_sq, g.integral, g.relative_error).unwrap();
    }
    println!();

    // ═══ §G. DISPERSION RELATION ═══
    println!("  {BOLD}{WHITE}═══ §G. DISPERSION RELATION — min |λ_j-λ_k| ≥ 1/(N+1) ═══{RESET}");
    println!("  {DIM}  log_frequencies_separated (FrequencySeparation.lean){RESET}");
    println!();

    let mut tsv_g = fs::File::create("results/dispersion_relation.tsv").unwrap();
    writeln!(tsv_g, "N\tmin_gap\ttheoretical_bound\tratio\tj\tk").unwrap();

    println!("    {DIM}     N │ min gap    │ 1/(N+1)    │ ratio  │ pair{RESET}");
    for &n in &test_ns {
        let d = spectral::dispersion_relation(n);
        let ok = d.ratio >= 1.0 - 1e-10;
        println!("    {:>5} │ {:>10.6} │ {:>10.6} │ {:>6.3} │ ({},{}) {}",
            n, d.min_gap, d.theoretical_bound, d.ratio, d.pair.0, d.pair.1, check(ok));
        writeln!(tsv_g, "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{}\t{}",
            n, d.min_gap, d.theoretical_bound, d.ratio, d.pair.0, d.pair.1).unwrap();
    }
    println!();

    // ═══ §H. SCALING LAW ═══
    println!("  {BOLD}{WHITE}═══ §H. SCALING LAW — equipartition test ═══{RESET}");
    println!("  {DIM}  Geometric frustration: does each channel carry ≈25% as N→∞?{RESET}");
    println!();

    if partition_results.len() >= 2 {
        let large: Vec<&characters::ChannelBreakdown> = partition_results.iter()
            .filter(|b| b.n >= 100).collect();
        if large.len() >= 2 {
            for i in 0..4 {
                let fracs: Vec<f64> = large.iter().map(|b| b.channel_fraction[i]).collect();
                let f_min = fracs.iter().cloned().fold(f64::INFINITY, f64::min);
                let f_max = fracs.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
                let f_last = *fracs.last().unwrap();
                let near_quarter = (f_last - 0.25).abs() < 0.15;
                println!("    {} range (N≥100): [{MAGENTA}{f_min:.6}{RESET}, {MAGENTA}{f_max:.6}{RESET}]  latest={YELLOW}{f_last:.6}{RESET}  {}",
                    characters::CHI_NAMES[i], check(near_quarter));
            }
        }
    }
    println!();

    // ═══ CERTIFICATE ═══
    let all_partition_ok = partition_results.iter().all(|b| b.mpfr_partition_error < 1e-100);
    let all_dispersion_ok = test_ns.iter().all(|&n| spectral::dispersion_relation(n).ratio >= 1.0 - 1e-10);

    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}ROTOR SPECTROSCOPY — CERTIFICATE{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  Precision: {YELLOW}{}-bit MPFR{RESET}    Threads: {YELLOW}{threads}{RESET}    Max N: {YELLOW}{last_n}{RESET}", weights::P);
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§A. Sieve{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    {} μ(k) validated at {} test points", check(sieve_ok), test_vals.len());
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§B. Characters{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    {} Orthogonality verified (16/16 entries)", check(orth_ok));
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§C. Energy Partition{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    {} (1/4)·Σ E_i = Σ|v_k|² for all N (err < 1e-12)", check(all_partition_ok));
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}§G. Dispersion{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}    {} min|λ_j-λ_k| ≥ 1/(N+1) for all N", check(all_dispersion_ok));
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}VERDICT{RESET}");
    if all_partition_ok && all_dispersion_ok && orth_ok && sieve_ok {
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ Stained Glass Rotors CONFIRMED{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ discrete_energy_partition numerically validated{RESET}");
        println!("  {BOLD}{CYAN}║{RESET}    {GREEN}{BOLD}✓ log_frequencies_separated numerically validated{RESET}");
    } else {
        println!("  {BOLD}{CYAN}║{RESET}    {YELLOW}{BOLD}⚠ PARTIAL — see individual results{RESET}");
    }
    println!("  {BOLD}{CYAN}║{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    // JSON certificate
    let cert = format!(r#"{{
  "experiment": "Cathedral Rotor Spectroscopy",
  "precision_bits": 512,
  "threads": {threads},
  "timestamp": "{}",
  "target": "discrete_energy_partition (GallagherPartition.lean)",
  "max_N_tested": {last_n},
  "sieve_validated": {sieve_ok},
  "orthogonality_verified": {orth_ok},
  "partition_identity_verified": {all_partition_ok},
  "dispersion_verified": {all_dispersion_ok},
  "channel_fractions_at_max_N": [{:.6}, {:.6}, {:.6}, {:.6}],
  "elapsed_seconds": {:.3}
}}"#,
        chrono::Utc::now().to_rfc3339(),
        partition_results.last().map(|b| b.channel_fraction[0]).unwrap_or(0.0),
        partition_results.last().map(|b| b.channel_fraction[1]).unwrap_or(0.0),
        partition_results.last().map(|b| b.channel_fraction[2]).unwrap_or(0.0),
        partition_results.last().map(|b| b.channel_fraction[3]).unwrap_or(0.0),
        t0.elapsed().as_secs_f64()
    );
    fs::write("results/certificate.json", &cert).unwrap();

    println!();
    println!("  {BOLD}{WHITE}Total:{RESET} {GREEN}{}{RESET} ({threads} threads)",
        elapsed(t0.elapsed().as_secs_f64()));
    println!("  {BOLD}{WHITE}Output:{RESET} results/{{energy_partition,residue_classes,spectral_profile,gallagher_mvt,dispersion_relation}}.tsv");
    println!("  {BOLD}{WHITE}Certificate:{RESET} results/certificate.json");
    println!();
}
