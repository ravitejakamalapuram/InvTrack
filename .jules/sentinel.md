## 2024-04-07 - Missing CRC verification in ZIP import

**Vulnerability:** The data import feature decoded ZIP files using `ZipDecoder().decodeBytes(zipBytes)` without explicitly setting `verify: true`, which defaults to `false` in the `archive` package.
**Learning:** The default behavior of `ZipDecoder` does not verify CRC checksums, meaning malformed or corrupted ZIP files could be extracted without error, potentially leading to instability or security risks during the import process.
**Prevention:** Always explicitly set `verify: true` when decoding ZIP files with the `archive` package (`archive = ZipDecoder().decodeBytes(zipBytes, verify: true);`) to enforce integrity checks before extraction.