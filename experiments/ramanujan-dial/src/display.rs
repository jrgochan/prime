//! Display and classification utilities for the Ramanujan Dial.

use std::collections::HashSet;

/// The canonical colossal number sequence (Superior Highly Composites).
pub static COLOSSAL_SET: std::sync::LazyLock<HashSet<u64>> = std::sync::LazyLock::new(|| {
    [2u64, 6, 12, 60, 120, 360, 2520, 5040, 55440, 720720]
        .into_iter()
        .collect()
});

/// Format a large number with comma separators.
pub fn format_num(n: u64) -> String {
    let s = n.to_string();
    let mut result = String::new();
    for (i, ch) in s.chars().rev().enumerate() {
        if i > 0 && i % 3 == 0 {
            result.push(',');
        }
        result.push(ch);
    }
    result.chars().rev().collect()
}

/// Classify a number for display purposes.
pub fn classify(n: usize, hcn_set: &HashSet<usize>) -> &'static str {
    if COLOSSAL_SET.contains(&(n as u64)) {
        "COLOSSAL"
    } else if hcn_set.contains(&n) {
        "HCN"
    } else if is_prime(n) {
        "prime"
    } else {
        ""
    }
}

/// Simple trial-division primality test (sufficient for N ≤ 10⁷).
pub fn is_prime(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n.is_multiple_of(2) || n.is_multiple_of(3) {
        return false;
    }
    let mut i = 5;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) {
            return false;
        }
        i += 6;
    }
    true
}

/// Brute-force divisor count (for numbers outside the sieve table).
pub fn count_divisors(n: usize) -> usize {
    if n <= 1 {
        return n;
    }
    let mut c = 0;
    let mut d = 1;
    while d * d <= n {
        if n.is_multiple_of(d) {
            c += 1;
            if d != n / d {
                c += 1;
            }
        }
        d += 1;
    }
    c
}
