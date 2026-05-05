fn main() {
    // Link against Apple Accelerate framework for LAPACK (dsyevd)
    // This is always available on macOS — no extra install needed
    #[cfg(target_os = "macos")]
    {
        println!("cargo:rustc-link-lib=framework=Accelerate");
    }
}
