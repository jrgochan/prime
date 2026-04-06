fn gcd(mut a: u64, mut b: u64) -> u64 {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

fn frac(x: f64) -> f64 { x - x.floor() }

fn gram_entry(j: u64, k: u64, n: u64) -> f64 {
    let mut s = 0.0;
    for i in 1..=n {
        let x = (i as f64 - 0.5) / n as f64;
        s += frac(j as f64 / x) * frac(k as f64 / x) / n as f64;
    }
    s
}

fn main() {
    let n_quad = 50000u64;
    
    println!("Testing: gramEntry(j,k) - 1/4 ≤ gcd/(jk) + 1/(4·max(j,k))");
    println!("{:<6} {:<6} {:>12} {:>12} {:>12} {:>8}",
             "j", "k", "GE-1/4", "gcd/(jk)", "+1/(4max)", "OK?");
    println!("{}", "-".repeat(62));

    let mut max_excess: f64 = -999.0;
    let mut worst = (0u64, 0u64);
    let mut pass = true;

    for j in 1..=80u64 {
        for k in (j+1)..=80 {
            let ge = gram_entry(j, k, n_quad);
            let excess = ge - 0.25;
            let g = gcd(j, k) as f64;
            let bound = g / (j as f64 * k as f64) + 1.0 / (4.0 * (j.max(k) as f64));
            let diff = excess - bound;
            
            if diff > max_excess {
                max_excess = diff;
                worst = (j, k);
            }
            
            if diff > 0.001 { // tolerance for numerical integration
                println!("{:<6} {:<6} {:>12.8} {:>12.8} {:>12.8} FAIL  diff={:.6e}",
                         j, k, excess, g/(j as f64 * k as f64), 
                         1.0/(4.0 * j.max(k) as f64), diff);
                pass = false;
            }
        }
    }

    let (wj, wk) = worst;
    let g = gcd(wj, wk) as f64;
    println!();
    println!("Worst case: j={}, k={}", wj, wk);
    println!("  GE-1/4 = {:.8}", gram_entry(wj, wk, n_quad) - 0.25);
    println!("  bound  = {:.8}", g/(wj as f64 * wk as f64) + 1.0/(4.0 * wj.max(wk) as f64));
    println!("  excess = {:.8e}", max_excess);
    println!();
    println!("Overall: {}", if pass { "PASS ✓" } else { "FAIL ✗" });
}
