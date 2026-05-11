#![allow(unused, dead_code)]
//! Compare index-1 vs index-2 start for aggregate excess.
//! Tests whether the 1/4 mean holds for the actual NB basis (k≥2).

use offdiag_excess::gram_entry;
use rayon::prelude::*;

fn run(start_idx: usize, n: usize) -> (f64, f64) {
    let pairs: Vec<(usize, usize)> = (0..n)
        .flat_map(|i| (0..n).filter(move |&j| i != j).map(move |j| (i, j)))
        .collect();

    let results: Vec<(f64, f64)> = pairs
        .par_chunks(1000)
        .map(|chunk| {
            let mut excess = 0.0;
            let mut offdiag = 0.0;
            for &(i, j) in chunk {
                let g = gram_entry(i + start_idx, j + start_idx);
                offdiag += g;
                excess += g - 0.25;
            }
            (excess, offdiag)
        })
        .collect();

    let total_excess: f64 = results.iter().map(|r| r.0).sum();
    let total_offdiag: f64 = results.iter().map(|r| r.1).sum();
    (total_excess, total_offdiag / (n * (n - 1)) as f64)
}

fn main() {
    let sizes = vec![50, 100, 200, 300, 500, 1000];

    eprintln!("Comparing index-1 start vs index-2 start\n");
    eprintln!(
        "{:>5} {:>12} {:>10} {:>10} {:>12} {:>10} {:>10}",
        "n", "excess(1)", "ex/n(1)", "avg(1)", "excess(2)", "ex/n(2)", "avg(2)"
    );
    eprintln!("{}", "-".repeat(75));

    for n in sizes {
        let start = std::time::Instant::now();
        let (ex1, avg1) = run(1, n);
        let (ex2, avg2) = run(2, n);
        let elapsed = start.elapsed();
        eprintln!(
            "{:5} {:12.3} {:10.4} {:10.6} {:12.3} {:10.4} {:10.6}  ({:.1}s)",
            n,
            ex1,
            ex1 / n as f64,
            avg1,
            ex2,
            ex2 / n as f64,
            avg2,
            elapsed.as_secs_f64()
        );
    }
}
