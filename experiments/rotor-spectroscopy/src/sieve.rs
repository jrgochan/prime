//! Möbius sieve — identical to crown-cancellation for consistency

pub fn mobius_sieve(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    let mut spf = vec![0usize; n + 1];
    mu[1] = 1;
    for p in 2..=n {
        if spf[p] != 0 { continue; }
        spf[p] = p;
        for m in (2 * p..=n).step_by(p) {
            if spf[m] == 0 { spf[m] = p; }
        }
    }
    for k in 2..=n {
        let mut val = k;
        let mut nf = 0u32;
        let mut sq = false;
        while val > 1 {
            let p = spf[val];
            let mut c = 0;
            while val % p == 0 { val /= p; c += 1; }
            if c > 1 { sq = true; break; }
            nf += 1;
        }
        if sq { mu[k] = 0; }
        else if nf % 2 == 0 { mu[k] = 1; }
        else { mu[k] = -1; }
    }
    mu
}
