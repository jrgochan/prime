use std::io::Write;

fn gcd(mut a: u64, mut b: u64) -> u64 {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

fn main() {
    // Pure arithmetic: no gramEntry integration needed
    // Just verify the two component sums that feed offdiag_excess_sum_le
    let targets: Vec<u64> = vec![1000, 5000, 10000, 20000, 50000, 100000];
    
    let mut out = std::fs::File::create("sum_bounds_extended.csv").unwrap();
    writeln!(out, "N,sum_gcd2_over_12ij,sum_inv_4max,total,ratio_to_3N").unwrap();

    println!("{:<10} {:>18} {:>18} {:>14} {:>14}",
             "N", "Σg²/(12ij)", "Σ1/(4max)", "total/N", "total/3N");
    println!("{}", "-".repeat(80));

    for &n in &targets {
        let mut s_gcd2: f64 = 0.0;
        let mut s_max: f64 = 0.0;

        for i in 1..n {
            for j in (i+1)..n {
                let g = gcd(i, j) as f64;
                let fi = i as f64;
                let fj = j as f64;
                // Both (i,j) and (j,i) contribute symmetrically
                s_gcd2 += 2.0 * g * g / (12.0 * fi * fj);
                s_max  += 2.0 / (4.0 * fj); // max(i,j) = j since j > i
            }
        }

        let nf = n as f64;
        let total = s_gcd2 + s_max;

        println!("{:<10} {:>18.6} {:>18.6} {:>14.8} {:>14.8}",
                 n, s_gcd2, s_max, total/nf, total/(3.0*nf));

        writeln!(out, "{},{:.10},{:.10},{:.10},{:.10}",
                 n, s_gcd2, s_max, total, total/(3.0*nf)).unwrap();
    }

    println!();
    println!("If total/3N < 1.0 for all N, the axiom offdiag_excess_sum_le holds.");
    println!("Theory predicts total/N → 2/3, so total/3N → 2/9 ≈ 0.222...");
    println!();
    println!("Results written to sum_bounds_extended.csv");
}
