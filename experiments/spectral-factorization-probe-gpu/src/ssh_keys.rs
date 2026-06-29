//! SSH Key Generation & Parameter Extraction
//!
//! Generates RSA and ECDSA SSH keys, then extracts the mathematical
//! objects (RSA modulus/factors, ECDSA curve parameters) for spectral
//! probe analysis.
//!
//! Strategy:
//!   - **Small RSA** (64–512 bit): Generated via `openssl genrsa`.
//!     Factors fit in u64, so ALL probes (H1–H6) can run.
//!   - **Standard RSA** (2048, 4096): Generated via `ssh-keygen`.
//!     Too large for Gram matrices. Only H3 (Vasyunin, mod-reduced)
//!     and H4 (Möbius local structure) are applicable.
//!   - **ECDSA** (P-256, P-384): Generated via `ssh-keygen`.
//!     No semiprime structure, but we examine the private key scalar
//!     and curve order for any spectral fingerprint.

use crate::keygen::SemiprimeKey;
use std::fs;
use std::path::Path;
use std::process::Command;

// ═══════════════════════════════════════════════════════════════
// DATA TYPES
// ═══════════════════════════════════════════════════════════════

/// An RSA key with extracted mathematical parameters.
#[derive(Debug, Clone, serde::Serialize)]
pub struct RsaKeyInfo {
    pub bits: u32,
    pub key_path: String,
    pub modulus_hex: String,
    pub prime1_hex: String,
    pub prime2_hex: String,
    pub e: u64,
    /// If N fits in u64, we store it directly for probe compatibility
    pub semiprime: Option<SemiprimeKey>,
    /// Full modulus as big-endian bytes (for large keys)
    #[serde(skip)]
    pub modulus_bytes: Vec<u8>,
}

/// An ECDSA key with extracted parameters.
#[derive(Debug, Clone, serde::Serialize)]
pub struct EcdsaKeyInfo {
    pub curve: String,
    pub bits: u32,
    pub key_path: String,
    pub private_key_hex: String,
    /// Curve order (hex)
    pub curve_order_hex: String,
    /// If private key fits in u64, store it for analysis
    pub private_key_u64: Option<u64>,
}

/// Full SSH key test suite.
#[derive(Debug, Clone, serde::Serialize)]
pub struct SshKeySet {
    pub output_dir: String,
    pub rsa_keys: Vec<RsaKeyInfo>,
    pub ecdsa_keys: Vec<EcdsaKeyInfo>,
    /// Only the RSA keys whose N fits in u64 — ready for probe pipeline
    pub tractable_semiprimes: Vec<SemiprimeKey>,
}

// ═══════════════════════════════════════════════════════════════
// KEY GENERATION
// ═══════════════════════════════════════════════════════════════

/// Generate a complete SSH key test suite.
///
/// Creates keys in `output_dir/ssh_keys/` and extracts all parameters.
pub fn generate_ssh_test_suite(output_dir: &Path) -> SshKeySet {
    let key_dir = output_dir.join("ssh_keys");
    fs::create_dir_all(&key_dir).expect("Failed to create SSH key directory");

    println!("  ╔═══════════════════════════════════════════════════════════╗");
    println!("  ║ SSH KEY GENERATION & PARAMETER EXTRACTION                ║");
    println!("  ╚═══════════════════════════════════════════════════════════╝\n");

    let mut rsa_keys = Vec::new();
    let mut ecdsa_keys = Vec::new();
    let mut tractable_semiprimes = Vec::new();

    // ── Small RSA keys (tractable for full Gram analysis) ──
    // OpenSSL 3.x rejects keys < 512 bits. For sub-512-bit "keys",
    // we generate synthetic semiprimes using our keygen module to ensure
    // the H1–H6 pipeline always has tractable material.
    for bits in [64u32, 128, 256, 512] {
        println!(
            "  Generating RSA-{} key (small, for full probe analysis)...",
            bits
        );
        match generate_small_rsa(&key_dir, bits) {
            Ok(info) => {
                if let Some(ref sp) = info.semiprime {
                    println!("    ✓ N = {} = {} × {} ({}-bit)", sp.n, sp.p, sp.q, sp.bits);
                    tractable_semiprimes.push(sp.clone());
                } else {
                    println!(
                        "    ✓ N = {} ({} hex digits, too large for u64)",
                        &info.modulus_hex[..20.min(info.modulus_hex.len())],
                        info.modulus_hex.len()
                    );
                }
                rsa_keys.push(info);
            }
            Err(e) => {
                println!("    ✗ OpenSSL refused: {}", e);
                // Fallback: generate synthetic semiprimes once for probe analysis.
                // OpenSSL 3.x rejects all keys < 512 bits, so we generate
                // synthetic material on the first failure and skip the rest.
                if tractable_semiprimes.is_empty() {
                    println!("    → Generating synthetic semiprimes via keygen fallback...");
                    let synth_keys = crate::keygen::generate_test_suite();
                    for class in &synth_keys {
                        for key in &class.keys {
                            tractable_semiprimes.push(key.clone());
                        }
                    }
                    println!(
                        "    ✓ Added {} synthetic semiprimes for H1–H6 probe analysis",
                        tractable_semiprimes.len()
                    );
                }
            }
        }
    }

    // ── Standard SSH RSA keys ──
    for bits in [2048u32, 4096] {
        println!(
            "  Generating SSH RSA-{} key (standard, password=\"password\")...",
            bits
        );
        match generate_ssh_rsa(&key_dir, bits, "password") {
            Ok(info) => {
                let n_preview = if info.modulus_hex.len() > 32 {
                    format!(
                        "{}...{}",
                        &info.modulus_hex[..16],
                        &info.modulus_hex[info.modulus_hex.len() - 16..]
                    )
                } else {
                    info.modulus_hex.clone()
                };
                println!("    ✓ N = 0x{} ({}-bit)", n_preview, bits);
                rsa_keys.push(info);
            }
            Err(e) => println!("    ✗ Failed: {}", e),
        }
    }

    // ── ECDSA keys ──
    for (curve, bits) in [("prime256v1", 256u32), ("secp384r1", 384)] {
        let name = if bits == 256 { "P-256" } else { "P-384" };
        println!(
            "  Generating SSH ECDSA {} key (password=\"password\")...",
            name
        );
        match generate_ssh_ecdsa(&key_dir, curve, bits, "password") {
            Ok(info) => {
                let preview = if info.private_key_hex.len() > 32 {
                    format!("{}...", &info.private_key_hex[..32])
                } else {
                    info.private_key_hex.clone()
                };
                println!("    ✓ curve={}, d = 0x{}", info.curve, preview);
                ecdsa_keys.push(info);
            }
            Err(e) => println!("    ✗ Failed: {}", e),
        }
    }

    println!(
        "\n  Summary: {} RSA keys ({} tractable), {} ECDSA keys\n",
        rsa_keys.len(),
        tractable_semiprimes.len(),
        ecdsa_keys.len()
    );

    SshKeySet {
        output_dir: key_dir.to_string_lossy().to_string(),
        rsa_keys,
        ecdsa_keys,
        tractable_semiprimes,
    }
}

// ═══════════════════════════════════════════════════════════════
// RSA KEY GENERATION
// ═══════════════════════════════════════════════════════════════

/// Generate a small RSA key using `openssl genrsa` (no minimum size enforced).
fn generate_small_rsa(key_dir: &Path, bits: u32) -> Result<RsaKeyInfo, String> {
    let key_path = key_dir.join(format!("rsa_{}.pem", bits));

    // Generate key
    let output = Command::new("openssl")
        .args([
            "genrsa",
            "-out",
            &key_path.to_string_lossy(),
            &bits.to_string(),
        ])
        .output()
        .map_err(|e| format!("openssl genrsa failed: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "openssl genrsa exit {}: {}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    // Extract parameters
    extract_rsa_params(&key_path, bits, None)
}

/// Generate a standard SSH RSA key using `ssh-keygen`.
fn generate_ssh_rsa(key_dir: &Path, bits: u32, passphrase: &str) -> Result<RsaKeyInfo, String> {
    let key_path = key_dir.join(format!("id_rsa_{}", bits));

    // Remove existing key files first
    let _ = fs::remove_file(&key_path);
    let _ = fs::remove_file(key_path.with_extension("pub"));

    // Generate SSH key in PEM format (so openssl can read it)
    let output = Command::new("ssh-keygen")
        .args([
            "-t",
            "rsa",
            "-b",
            &bits.to_string(),
            "-N",
            passphrase,
            "-m",
            "PEM",
            "-f",
            &key_path.to_string_lossy(),
            "-q", // quiet
        ])
        .output()
        .map_err(|e| format!("ssh-keygen failed: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "ssh-keygen exit {}: {}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    extract_rsa_params(&key_path, bits, Some(passphrase))
}

/// Extract RSA modulus and prime factors from a PEM key file.
fn extract_rsa_params(
    key_path: &Path,
    bits: u32,
    passphrase: Option<&str>,
) -> Result<RsaKeyInfo, String> {
    let key_path_str = key_path.to_string_lossy().to_string();
    let mut args = vec!["rsa", "-in", key_path_str.as_str(), "-text", "-noout"];
    let pass_arg;
    if let Some(pw) = passphrase {
        pass_arg = format!("pass:{}", pw);
        args.extend(["-passin", pass_arg.as_str()]);
    }

    let output = Command::new("openssl")
        .args(&args)
        .output()
        .map_err(|e| format!("openssl rsa -text failed: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "openssl rsa -text exit {}: {}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    let text = String::from_utf8_lossy(&output.stdout);

    let modulus_hex = extract_hex_field(&text, "modulus:")
        .ok_or_else(|| "Failed to extract modulus".to_string())?;
    let prime1_hex = extract_hex_field(&text, "prime1:")
        .ok_or_else(|| "Failed to extract prime1".to_string())?;
    let prime2_hex = extract_hex_field(&text, "prime2:")
        .ok_or_else(|| "Failed to extract prime2".to_string())?;
    let e = extract_public_exponent(&text).unwrap_or(65537);

    let modulus_bytes = hex_to_bytes(&modulus_hex);

    // Try to fit into u64 for probe compatibility
    let semiprime = if modulus_bytes.len() <= 8 {
        let n = bytes_to_u64(&modulus_bytes);
        let p = bytes_to_u64(&hex_to_bytes(&prime1_hex));
        let q = bytes_to_u64(&hex_to_bytes(&prime2_hex));
        if n > 0 && p > 0 && q > 0 {
            let (p, q) = if p < q { (p, q) } else { (q, p) };
            Some(SemiprimeKey {
                n,
                p,
                q,
                bits: 64 - n.leading_zeros(),
            })
        } else {
            None
        }
    } else {
        None
    };

    Ok(RsaKeyInfo {
        bits,
        key_path: key_path.to_string_lossy().to_string(),
        modulus_hex,
        prime1_hex,
        prime2_hex,
        e,
        semiprime,
        modulus_bytes,
    })
}

// ═══════════════════════════════════════════════════════════════
// ECDSA KEY GENERATION
// ═══════════════════════════════════════════════════════════════

/// Generate an ECDSA SSH key using `ssh-keygen`.
fn generate_ssh_ecdsa(
    key_dir: &Path,
    curve: &str,
    bits: u32,
    passphrase: &str,
) -> Result<EcdsaKeyInfo, String> {
    let key_path = key_dir.join(format!("id_ecdsa_{}", bits));

    // Remove existing
    let _ = fs::remove_file(&key_path);
    let _ = fs::remove_file(key_path.with_extension("pub"));

    // ssh-keygen -t ecdsa needs the bit size for the curve selection
    let ecdsa_bits = if bits == 256 { "256" } else { "384" };

    let output = Command::new("ssh-keygen")
        .args([
            "-t",
            "ecdsa",
            "-b",
            ecdsa_bits,
            "-N",
            passphrase,
            "-m",
            "PEM",
            "-f",
            &key_path.to_string_lossy(),
            "-q",
        ])
        .output()
        .map_err(|e| format!("ssh-keygen ecdsa failed: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "ssh-keygen ecdsa exit {}: {}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    // Extract ECDSA private key
    let ec_output = Command::new("openssl")
        .args([
            "ec",
            "-in",
            &key_path.to_string_lossy(),
            "-text",
            "-noout",
            "-passin",
            &format!("pass:{}", passphrase),
        ])
        .output()
        .map_err(|e| format!("openssl ec -text failed: {}", e))?;

    if !ec_output.status.success() {
        return Err(format!(
            "openssl ec -text exit {}: {}",
            ec_output.status,
            String::from_utf8_lossy(&ec_output.stderr)
        ));
    }

    let text = String::from_utf8_lossy(&ec_output.stdout);

    let private_key_hex = extract_hex_field(&text, "priv:").unwrap_or_default();

    // Well-known curve orders
    let curve_order_hex = match curve {
        "prime256v1" => "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551".to_string(),
        "secp384r1"  => "ffffffffffffffffffffffffffffffffffffffffffffffffc7634d81f4372ddf581a0db248b0a77aecec196accc52973".to_string(),
        _ => String::new(),
    };

    let curve_name = match curve {
        "prime256v1" => "P-256",
        "secp384r1" => "P-384",
        _ => curve,
    };

    let priv_bytes = hex_to_bytes(&private_key_hex);
    let private_key_u64 = if priv_bytes.len() <= 8 {
        Some(bytes_to_u64(&priv_bytes))
    } else {
        None
    };

    Ok(EcdsaKeyInfo {
        curve: curve_name.to_string(),
        bits,
        key_path: key_path.to_string_lossy().to_string(),
        private_key_hex,
        curve_order_hex,
        private_key_u64,
    })
}

// ═══════════════════════════════════════════════════════════════
// HEX PARSING UTILITIES
// ═══════════════════════════════════════════════════════════════

/// Extract a hex-encoded big number field from openssl text output.
///
/// OpenSSL formats these as:
/// ```text
/// modulus:
///     00:ab:cd:ef:12:34:...
///     56:78:9a:bc:de:f0:...
/// ```
fn extract_hex_field(text: &str, field_name: &str) -> Option<String> {
    // Known RSA field names from openssl rsa -text output.
    // These MUST terminate hex continuation scanning.
    const RSA_FIELDS: &[&str] = &[
        "modulus:",
        "publicExponent:",
        "privateExponent:",
        "prime1:",
        "prime2:",
        "exponent1:",
        "exponent2:",
        "coefficient:",
    ];

    let lines: Vec<&str> = text.lines().collect();
    let start = lines
        .iter()
        .position(|l| l.trim().starts_with(field_name))?;

    let mut hex = String::new();

    // Check if the value is on the same line (e.g., "publicExponent: 65537 (0x10001)")
    let first_line = lines[start].trim();
    if let Some(rest) = first_line.strip_prefix(field_name) {
        let rest = rest.trim();
        // If it looks like a decimal with hex in parens, skip
        if rest.contains("(0x") {
            return None;
        }
        // If the rest is hex data on the same line
        if rest.contains(':') {
            hex.push_str(rest);
        }
    }

    // Collect continuation lines (indented, colon-separated hex)
    for line in lines.iter().skip(start + 1) {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            break;
        }
        // Stop if we hit another known RSA field
        if RSA_FIELDS.iter().any(|&f| trimmed.starts_with(f)) {
            break;
        }
        // Stop if the line doesn't look like hex data
        if !trimmed.contains(':') && !trimmed.chars().all(|c| c.is_ascii_hexdigit()) {
            break;
        }
        hex.push_str(trimmed);
    }

    // Clean: remove colons, leading "00", whitespace
    let hex = hex.replace([':', ' '], "");
    let hex = hex.trim_start_matches("00").to_string();
    if hex.is_empty() {
        return None;
    }
    Some(hex)
}

/// Extract the public exponent from openssl RSA text output.
fn extract_public_exponent(text: &str) -> Option<u64> {
    for line in text.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("publicExponent:") {
            // Format: "publicExponent: 65537 (0x10001)"
            let num_str = trimmed
                .strip_prefix("publicExponent:")?
                .split_whitespace()
                .next()?;
            return num_str.parse().ok();
        }
    }
    None
}

/// Convert a hex string to big-endian bytes.
fn hex_to_bytes(hex: &str) -> Vec<u8> {
    let hex = hex.replace([':', ' '], "");
    let hex = if hex.len() % 2 == 1 {
        format!("0{}", hex)
    } else {
        hex
    };
    (0..hex.len())
        .step_by(2)
        .filter_map(|i| u8::from_str_radix(&hex[i..i + 2], 16).ok())
        .collect()
}

/// Convert big-endian bytes to u64 (truncating if > 8 bytes).
fn bytes_to_u64(bytes: &[u8]) -> u64 {
    let mut result = 0u64;
    for &b in bytes.iter().take(8) {
        result = (result << 8) | b as u64;
    }
    result
}

// ═══════════════════════════════════════════════════════════════
// LARGE-KEY ANALYSIS UTILITIES
// ═══════════════════════════════════════════════════════════════

/// For large RSA keys that don't fit in u64, compute modular residues
/// for Vasyunin-like analysis.
///
/// Returns N mod m for small m values, which is sufficient for
/// the Vasyunin cotangent sum V(m, N mod m).
pub fn modular_residues(modulus_bytes: &[u8], moduli: &[u64]) -> Vec<(u64, u64)> {
    moduli
        .iter()
        .map(|&m| {
            let mut residue = 0u64;
            for &byte in modulus_bytes {
                residue = (residue * 256 + byte as u64) % m;
            }
            (m, residue)
        })
        .collect()
}

/// Compute number-theoretic properties of the private key scalar.
///
/// For ECDSA, the private key d is a random scalar in [1, n-1].
/// We check if its arithmetic neighbourhood shows any anomalies
/// compared to generic random numbers.
pub fn scalar_properties(d_hex: &str) -> ScalarProperties {
    let bytes = hex_to_bytes(d_hex);
    let d_u64 = if bytes.len() <= 8 {
        Some(bytes_to_u64(&bytes))
    } else {
        None
    };

    // Bit entropy estimate: how many trailing zeros?
    let trailing_zeros = bytes.iter().rev().take_while(|&&b| b == 0).count() * 8;

    // Hamming weight of the scalar
    let hamming_weight: u32 = bytes.iter().map(|b| b.count_ones()).sum();
    let total_bits = bytes.len() * 8;

    ScalarProperties {
        hex: d_hex.to_string(),
        byte_length: bytes.len(),
        hamming_weight,
        total_bits,
        hamming_ratio: hamming_weight as f64 / total_bits as f64,
        trailing_zero_bits: trailing_zeros,
        fits_u64: d_u64.is_some(),
        value_u64: d_u64,
    }
}

/// Number-theoretic properties of a scalar value.
#[derive(Debug, Clone, serde::Serialize)]
pub struct ScalarProperties {
    pub hex: String,
    pub byte_length: usize,
    pub hamming_weight: u32,
    pub total_bits: usize,
    pub hamming_ratio: f64,
    pub trailing_zero_bits: usize,
    pub fits_u64: bool,
    pub value_u64: Option<u64>,
}
