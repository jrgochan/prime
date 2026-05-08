//! Low-level HDF5 attribute read/write utilities.

/// Write a string attribute to an HDF5 location.
pub(crate) fn write_str_attr(loc: &hdf5::Location, name: &str, val: &str) -> hdf5::Result<()> {
    let attr = loc.new_attr::<hdf5::types::VarLenUnicode>()
        .shape(())
        .create(name)?;
    let s: hdf5::types::VarLenUnicode = val.parse().unwrap();
    attr.write_scalar(&s)?;
    Ok(())
}

/// Write a numeric scalar attribute.
pub(crate) fn write_scalar_attr<T: hdf5::H5Type>(
    loc: &hdf5::Location,
    name: &str,
    val: T,
) -> hdf5::Result<()> {
    let attr = loc.new_attr::<T>().shape(()).create(name)?;
    attr.write_scalar(&val)?;
    Ok(())
}

/// Read a string attribute from an HDF5 location.
pub(crate) fn read_str_attr(loc: &hdf5::Location, name: &str) -> hdf5::Result<String> {
    let attr = loc.attr(name)?;
    let s: hdf5::types::VarLenUnicode = attr.read_scalar()?;
    Ok(s.to_string())
}

/// Try to read a scalar attribute, returning None if it doesn't exist.
pub(crate) fn read_scalar_opt<T: hdf5::H5Type>(loc: &hdf5::Location, name: &str) -> Option<T> {
    loc.attr(name).ok().and_then(|a| a.read_scalar::<T>().ok())
}

/// Try to read a string attribute, returning None if it doesn't exist.
pub(crate) fn read_str_opt(loc: &hdf5::Location, name: &str) -> Option<String> {
    read_str_attr(loc, name).ok()
}

/// Get a rough ISO-8601-ish timestamp without pulling in chrono.
pub(crate) fn unix_timestamp() -> String {
    use std::time::SystemTime;
    let d = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default();
    format!("unix_{}", d.as_secs())
}

/// Try to read the current git commit hash (short).
pub(crate) fn git_commit_short() -> String {
    std::process::Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                String::from_utf8(o.stdout).ok().map(|s| s.trim().to_string())
            } else {
                None
            }
        })
        .unwrap_or_else(|| "unknown".to_string())
}

/// Get the hostname.
pub(crate) fn hostname() -> String {
    std::process::Command::new("hostname")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok().map(|s| s.trim().to_string()))
        .unwrap_or_else(|| "unknown".to_string())
}

/// SHA-256 of a byte slice, returned as hex string.
pub(crate) fn sha256_hex(data: &[u8]) -> String {
    use sha2::{Sha256, Digest};
    let mut hasher = Sha256::new();
    hasher.update(data);
    format!("{:x}", hasher.finalize())
}
