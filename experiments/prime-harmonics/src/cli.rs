//! Command-line argument parsing for the Prime Harmonics Explorer.

use crate::modes::hardy_z::HdMode;

/// Run configuration parsed from CLI arguments.
pub struct Config {
    pub prime_limit: usize,
    pub mode: Mode,
}

/// Which analysis mode to run.
pub enum Mode {
    /// Full analysis: prime choir, interference at zeros, energy landscape, predictions
    Full { num_zeros: usize },
    /// Fine scan around a specific height
    FineScan {
        center: f64,
        window: f64,
        steps: usize,
    },
    /// Zero hunting: scan a range for interference minima
    Hunt {
        t_start: f64,
        t_end: f64,
        steps: usize,
    },
    /// Phase portrait at a specific height
    Portrait {
        height: f64,
        top_primes: usize,
    },
    /// Energy sweep with optional CSV/JSON output
    Sweep {
        t_start: f64,
        t_end: f64,
        steps: usize,
        format: OutputFormat,
    },
    /// Democracy index for first N prime pairs
    Democracy { count: usize },
    /// Hardy Z zero finder — works at ANY height, no primes needed
    HardyZ {
        t_start: f64,
        t_end: f64,
        refine: bool,
        hd: HdMode,
    },
    /// Scaling benchmark — measure choir accuracy vs height
    Bench,
    /// Mirror mode — reconstruct primes from zeros
    Mirror { x_max: f64 },
    /// Eta mode — complete winding cancellation analysis
    Eta { n_max: usize, num_zeros: usize, verbose: bool },
    /// Anomaly mode — Bridge 2: Δ = G - R perturbation analysis
    Anomaly { n_max: usize },
    /// Dyson mode — The Nuclear Option: d²_opt = d²_free + scattering
    Dyson { n_max: usize },
    /// Confinement mode — Strong coupling table from HPDF .h5 files
    Confinement { h5_dir: String },
}

/// Output format for sweep mode.
pub enum OutputFormat {
    Terminal,
    Csv,
    Json,
}

pub fn parse_args() -> Config {
    let args: Vec<String> = std::env::args().collect();
    let mut prime_limit = 10_000;
    let mut mode = Mode::Full { num_zeros: 30 };

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--prime-limit" | "-p" => {
                i += 1;
                prime_limit = args[i].parse().expect("Expected number for --prime-limit");
            }
            "--zeros" | "-z" => {
                i += 1;
                let n: usize = args[i].parse().expect("Expected number for --zeros");
                mode = Mode::Full { num_zeros: n };
            }
            "--fine-scan" | "-f" => {
                i += 1;
                let center: f64 = args[i].parse().expect("Expected number for --fine-scan");
                let mut window = 1.0;
                let mut steps = 2000;
                while i + 1 < args.len() {
                    match args[i + 1].as_str() {
                        "--window" => {
                            i += 2;
                            window = args[i].parse().unwrap();
                        }
                        "--steps" => {
                            i += 2;
                            steps = args[i].parse().unwrap();
                        }
                        _ => break,
                    }
                }
                mode = Mode::FineScan {
                    center,
                    window,
                    steps,
                };
            }
            "--hunt" | "-h" => {
                i += 1;
                let t_start: f64 = args[i].parse().expect("Expected start for --hunt");
                i += 1;
                let t_end: f64 = args[i].parse().expect("Expected end for --hunt");
                let mut steps = 10_000;
                if i + 1 < args.len() && args[i + 1] == "--steps" {
                    i += 2;
                    steps = args[i].parse().unwrap();
                }
                mode = Mode::Hunt {
                    t_start,
                    t_end,
                    steps,
                };
            }
            "--portrait" => {
                i += 1;
                let height: f64 = args[i].parse().expect("Expected number for --portrait");
                let mut top_primes = 50;
                if i + 1 < args.len() && args[i + 1] == "--top-primes" {
                    i += 2;
                    top_primes = args[i].parse().unwrap();
                }
                mode = Mode::Portrait {
                    height,
                    top_primes,
                };
            }
            "--sweep" | "-s" => {
                i += 1;
                let t_start: f64 = args[i].parse().expect("Expected start for --sweep");
                i += 1;
                let t_end: f64 = args[i].parse().expect("Expected end for --sweep");
                let mut steps = 2000;
                let mut format = OutputFormat::Terminal;
                while i + 1 < args.len() {
                    match args[i + 1].as_str() {
                        "--steps" => {
                            i += 2;
                            steps = args[i].parse().unwrap();
                        }
                        "--csv" => {
                            i += 1;
                            format = OutputFormat::Csv;
                        }
                        "--json" => {
                            i += 1;
                            format = OutputFormat::Json;
                        }
                        _ => break,
                    }
                }
                mode = Mode::Sweep {
                    t_start,
                    t_end,
                    steps,
                    format,
                };
            }
            "--democracy" | "-d" => {
                i += 1;
                let count: usize = args[i].parse().expect("Expected number for --democracy");
                mode = Mode::Democracy { count };
            }
            "--hardy-z" | "--zfind" => {
                i += 1;
                let t_start: f64 = args[i].parse().expect("Expected start for --hardy-z");
                i += 1;
                let t_end: f64 = args[i].parse().expect("Expected end for --hardy-z");
                let mut refine = false;
                let mut hd = HdMode::Off;
                while i + 1 < args.len() {
                    match args[i + 1].as_str() {
                        "--stats" => { i += 1; refine = true; }
                        "--hd" => { i += 1; hd = HdMode::Fast; }
                        "--hd-full" => { i += 1; hd = HdMode::Full; }
                        _ => break,
                    }
                }
                mode = Mode::HardyZ {
                    t_start,
                    t_end,
                    refine,
                    hd,
                };
            }
            "--bench" | "--benchmark" => {
                mode = Mode::Bench;
            }
            "--mirror" => {
                i += 1;
                let x_max: f64 = if i < args.len() {
                    args[i].parse().unwrap_or(1000.0)
                } else {
                    1000.0
                };
                mode = Mode::Mirror { x_max };
            }
            "--eta" => {
                i += 1;
                let n_max: usize = if i < args.len() {
                    args[i].parse().unwrap_or(100_000)
                } else {
                    100_000
                };
                let mut num_zeros = 5;
                let mut verbose = false;
                while i + 1 < args.len() {
                    match args[i + 1].as_str() {
                        "--zeros" | "-z" => {
                            i += 2;
                            num_zeros = args[i].parse().unwrap();
                        }
                        "--verbose" | "-v" => {
                            i += 1;
                            verbose = true;
                        }
                        _ => break,
                    }
                }
                mode = Mode::Eta { n_max, num_zeros, verbose };
            }
            "--anomaly" => {
                i += 1;
                let n_max: usize = if i < args.len() {
                    args[i].parse().unwrap_or(30)
                } else {
                    30
                };
                mode = Mode::Anomaly { n_max };
            }
            "--dyson" => {
                i += 1;
                let n_max: usize = if i < args.len() {
                    args[i].parse().unwrap_or(100)
                } else {
                    100
                };
                mode = Mode::Dyson { n_max };
            }
            "--confinement" => {
                i += 1;
                let h5_dir = if i < args.len() && !args[i].starts_with('-') {
                    args[i].clone()
                } else {
                    i -= 1; // no arg consumed
                    "experiments/cache/hpdf".to_string()
                };
                mode = Mode::Confinement { h5_dir };
            }
            "--help" => {
                print_help();
                std::process::exit(0);
            }
            _ => {
                eprintln!("Unknown argument: {}", args[i]);
                print_help();
                std::process::exit(1);
            }
        }
        i += 1;
    }

    Config { prime_limit, mode }
}

pub fn print_help() {
    println!(
        r#"
🌀 Prime Harmonics Explorer — Each prime is a spinning oscillator.

Computational implementation of Cathedral/Spectral/PrimeHarmonics.lean.

USAGE:
    prime-harmonics [OPTIONS]

OPTIONS:
    -p, --prime-limit N     Sieve primes up to N (default: 10000)
    -z, --zeros N           Analyze first N known zeros (default: 30)
    -f, --fine-scan T       Fine scan around height T
        --window W          Half-width of fine scan (default: 1.0)
    -h, --hunt T1 T2        Hunt for zeros in range [T1, T2]
        --steps N           Resolution for scan/hunt (default: 2000/10000)
    --portrait T            Phase portrait at height T
        --top-primes N      Number of primes to show (default: 50)
    -s, --sweep T1 T2       Sweep |interference| from T1 to T2
        --csv               Output CSV format
        --json              Output JSON format
    -d, --democracy N       Democracy index for first N prime pairs
    --help                  Show this help

EXAMPLES:
    prime-harmonics                                    # Default full analysis
    prime-harmonics -p 1000000 -z 100                  # Large scale
    prime-harmonics -f 14.134 --window 0.1 -p 100000   # Fine scan first zero
    prime-harmonics -h 200 300 -p 100000               # Hunt zeros in [200,300]
    prime-harmonics --portrait 14.134725 --top-primes 100
    prime-harmonics -s 0 500 --steps 10000 --csv > energy.csv
    prime-harmonics -s 0 500 --json > energy.json
    prime-harmonics --hardy-z 10000 10100            # Find zeros at t=10000 (no primes needed)
    prime-harmonics --hardy-z 100000 100100 --stats  # Zeros + gap statistics
    prime-harmonics --eta 1000000                    # Eta cancellation to N=10^6
    prime-harmonics --eta 10000000 --zeros 10         # 10M with 10 zeros
"#
    );
}
