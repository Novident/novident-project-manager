//! Small std-only utilities.

use std::time::{SystemTime, UNIX_EPOCH};

/// Current UTC time as an ISO 8601 string (`2026-07-23T14:30:00Z`).
///
/// Implemented without external crates (civil-date conversion from days-since-
/// epoch, Hinnant's `civil_from_days`).
pub fn now_iso8601() -> String {
    iso8601_from_secs(now_secs())
}

/// UTC time `days` days from now, as an ISO 8601 string.
pub fn now_iso8601_after_days(days: u64) -> String {
    iso8601_from_secs(now_secs() + days * 86_400)
}

/// Current UTC time as a filesystem-safe stamp (`2026-08-28_00-24-24`).
pub fn now_file_stamp() -> String {
    now_iso8601()
        .replace(':', "-")
        .replace('T', "_")
        .replace('Z', "")
}

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn iso8601_from_secs(secs: u64) -> String {
    let days = (secs / 86_400) as i64;
    let rem = secs % 86_400;
    let (h, m, s) = (rem / 3600, (rem % 3600) / 60, rem % 60);
    let (y, mo, d) = civil_from_days(days);
    format!("{y:04}-{mo:02}-{d:02}T{h:02}:{m:02}:{s:02}Z")
}

/// Converts days since 1970-01-01 to a (year, month, day) civil date.
///
/// Port of Howard Hinnant's `civil_from_days` algorithm.
pub fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097) as u64; // [0, 146096]
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365; // [0, 399]
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100); // [0, 365]
    let mp = (5 * doy + 2) / 153; // [0, 11]
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32; // [1, 31]
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32; // [1, 12]
    (if m <= 2 { y + 1 } else { y }, m, d)
}

/// Serde helpers that round-trip a JSON-encoded [`String`] as the raw JSON it
/// represents. This keeps the `.nov` files in their object/array shape while the
/// FRB bridge exposes the value as a plain `String` (Dart does `jsonDecode`).
pub mod json_string {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};

    /// Serializes a JSON-encoded `String` as the raw JSON it represents.
    pub fn serialize<S>(value: &str, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let json: serde_json::Value =
            serde_json::from_str(value).map_err(serde::ser::Error::custom)?;
        json.serialize(serializer)
    }

    /// Deserializes raw JSON into a JSON-encoded `String`.
    pub fn deserialize<'de, D>(deserializer: D) -> Result<String, D::Error>
    where
        D: Deserializer<'de>,
    {
        let json = serde_json::Value::deserialize(deserializer)?;
        Ok(json.to_string())
    }

    /// `Option`-aware variants for optional JSON fields.
    pub mod opt {
        use serde::{Deserialize, Deserializer, Serializer};

        pub fn serialize<S>(value: &Option<String>, serializer: S) -> Result<S::Ok, S::Error>
        where
            S: Serializer,
        {
            match value {
                Some(s) => super::serialize(s, serializer),
                None => serializer.serialize_none(),
            }
        }

        pub fn deserialize<'de, D>(deserializer: D) -> Result<Option<String>, D::Error>
        where
            D: Deserializer<'de>,
        {
            let opt = Option::<serde_json::Value>::deserialize(deserializer)?;
            Ok(opt.map(|v| v.to_string()))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn civil_date_known_epoch() {
        // 1970-01-01 = day 0
        assert_eq!(civil_from_days(0), (1970, 1, 1));
        // 2000-01-01
        assert_eq!(civil_from_days(10_957), (2000, 1, 1));
        // 2026-07-23
        assert_eq!(civil_from_days(20_657), (2026, 7, 23));
    }

    #[test]
    fn now_iso8601_format() {
        let now = now_iso8601();
        assert!(now.ends_with('Z'), "expected UTC suffix: {now}");
        assert_eq!(now.len(), 20, "expected YYYY-MM-DDTHH:MM:SSZ: {now}");
    }
}
