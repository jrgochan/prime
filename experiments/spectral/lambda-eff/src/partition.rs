//! Octonionic residue class partition.
//!
//! Partitions {2, ..., N} into 8 classes based on k mod 8.
//! These correspond to the 8 residue classes of the octonionic partition
//! used in the FiniteDimReduction proof.

/// The 8 residue classes: indices k where k ≡ m (mod 8)
pub fn partition(n: usize) -> Vec<Vec<usize>> {
    let mut classes: Vec<Vec<usize>> = (0..8).map(|_| Vec::new()).collect();
    for k in 2..=n {
        classes[k % 8].push(k);
    }
    classes
}

/// Pretty names for the 8 classes
pub fn class_name(m: usize) -> &'static str {
    match m {
        0 => "S₀ (≡0 mod 8)",
        1 => "S₁ (≡1 mod 8)",
        2 => "S₂ (≡2 mod 8)",
        3 => "S₃ (≡3 mod 8)",
        4 => "S₄ (≡4 mod 8)",
        5 => "S₅ (≡5 mod 8)",
        6 => "S₆ (≡6 mod 8)",
        7 => "S₇ (≡7 mod 8)",
        _ => "S? (unknown)",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_partition_coverage() {
        let classes = partition(20);
        let mut all: Vec<usize> = classes.into_iter().flatten().collect();
        all.sort();
        let expected: Vec<usize> = (2..=20).collect();
        assert_eq!(all, expected);
    }

    #[test]
    fn test_partition_correctness() {
        let classes = partition(16);
        // Class 2 (≡2 mod 8): 2, 10
        assert!(classes[2].contains(&2));
        assert!(classes[2].contains(&10));
        // Class 0 (≡0 mod 8): 8, 16
        assert!(classes[0].contains(&8));
        assert!(classes[0].contains(&16));
    }
}
