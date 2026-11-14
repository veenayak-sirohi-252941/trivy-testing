# Comparison tools

- `compare_results.py --run-dir PATH` maps sanitized filesystem findings to catalog lines, computes category coverage, misses, negative-case findings, overlaps, unmatched results, and history statistics.
- `generate_summary.py PATH` renders a human-readable report from the saved comparison JSON.
- `validate_catalog.py` checks ID uniqueness, path existence, classifications, safe redaction markers, and JSON/CSV parity.

No comparison tool reads or prints raw scanner output.

The standard scanner runner overwrites `results/runs/latest/` on every run. Open its `summary.md` for the human-readable comparison.
