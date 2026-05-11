//! Sieve-based divisor counting and Highly Composite Number discovery.
//!
//! Uses an O(N log N) sieve to compute divisor counts for all n ≤ limit,
//! then scans for records (HCNs) in a single pass.

/// Sieve-based divisor count table: d(n) for n=0..=limit.
///
/// Each divisor `d` iterates through its multiples.
/// Complexity: O(N log N) — the harmonic series sum.
pub fn divisor_count_sieve(limit: usize) -> Vec<u32> {
    let mut d = vec![0u32; limit + 1];
    for i in 1..=limit {
        let mut m = i;
        while m <= limit {
            d[m] += 1;
            m += i;
        }
    }
    d
}

/// Find Highly Composite Numbers from a precomputed divisor sieve.
///
/// An HCN is an integer whose divisor count exceeds all smaller integers.
/// Returns a sorted vector of HCN values.
pub fn find_hcn_from_sieve(div_table: &[u32]) -> Vec<usize> {
    let mut hcns = Vec::new();
    let mut max_d = 0u32;
    for n in 1..div_table.len() {
        if div_table[n] > max_d {
            max_d = div_table[n];
            hcns.push(n);
        }
    }
    hcns
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_divisor_sieve_small() {
        let d = divisor_count_sieve(12);
        assert_eq!(d[1], 1); // 1 has 1 divisor
        assert_eq!(d[6], 4); // 6 has divisors 1,2,3,6
        assert_eq!(d[12], 6); // 12 has divisors 1,2,3,4,6,12
    }

    #[test]
    fn test_hcn_discovery() {
        let d = divisor_count_sieve(120);
        let hcns = find_hcn_from_sieve(&d);
        // First few HCNs: 1, 2, 4, 6, 12, 24, 36, 48, 60, 120
        assert!(hcns.contains(&1));
        assert!(hcns.contains(&12));
        assert!(hcns.contains(&60));
        assert!(hcns.contains(&120));
    }
}
