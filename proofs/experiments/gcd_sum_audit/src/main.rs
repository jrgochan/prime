fn gcd(mut a: u64, mut b: u64) -> u64 {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}

fn main() {
    println!("{:<8} {:>18} {:>18} {:>18} {:>12}",
             "N", "Σ_g≤12 g/(ij)", "Σ_g>12 1/12", "total_excess", "2(N-1)");
    println!("{}", "-".repeat(80));

    for &n in &[10u64, 50, 100, 500, 1000, 5000, 10000, 20000] {
        let mut sum_small_gcd: f64 = 0.0;
        let mut sum_large_gcd: f64 = 0.0;

        for i in 1..n {
            for j in 1..n {
                if i != j {
                    let g = gcd(i, j);
                    let fi = i as f64;
                    let fj = j as f64;
                    if g <= 12 {
                        sum_small_gcd += g as f64 / (fi * fj);
                    } else {
                        sum_large_gcd += 1.0 / 12.0;
                    }
                }
            }
        }

        let two_n1 = 2.0 * (n as f64 - 1.0);
        let total = sum_small_gcd + sum_large_gcd;

        println!("{:<8} {:>18.6} {:>18.6} {:>18.6} {:>12.1}",
                 n, sum_small_gcd, sum_large_gcd, total, two_n1);
    }

    // Also check: count pairs with gcd > 12
    println!();
    println!("{:<8} {:>15} {:>15} {:>15}",
             "N", "pairs_g>12", "total_pairs", "fraction");
    println!("{}", "-".repeat(55));
    for &n in &[100u64, 500, 1000, 5000] {
        let mut count_large: u64 = 0;
        let total = (n - 1) * (n - 2);
        for i in 1..n {
            for j in 1..n {
                if i != j && gcd(i, j) > 12 {
                    count_large += 1;
                }
            }
        }
        println!("{:<8} {:>15} {:>15} {:>15.6}",
                 n, count_large, total, count_large as f64 / total as f64);
    }
}
