//! Democracy index mode — irrationality of log(p₁)/log(p₂).

use cathedral_utils::harmonics::{continued_fraction, PrimeOscillatorBank};

pub fn run(bank: &PrimeOscillatorBank, count: usize) {
    let n = count.min(bank.len());
    println!("🌀 DEMOCRACY INDEX — first {} primes", n);
    println!("   log(p₁)/log(p₂) is IRRATIONAL for distinct primes (PROVED in Lean!)");
    println!();
    println!("        p₁ /     p₂   log(p₁)/log(p₂)       CF Expansion");
    println!("    ────── / ──────  ──────────────────  ─────────────────────────");

    for i in 0..n {
        for j in (i + 1)..n {
            let ratio = bank.log_p[i] / bank.log_p[j];
            let cf = continued_fraction(ratio, 12);
            let cf_str = cf
                .iter()
                .map(|x| x.to_string())
                .collect::<Vec<_>>()
                .join(", ");
            println!(
                "    {:>6} / {:>6}  {:>18.14}  [{}]",
                bank.primes[i], bank.primes[j], ratio, cf_str
            );
        }
    }
}
