# Scanner runs

The latest scan replaces `results/runs/latest/` on every run. The directory contains `metadata.json` (image IDs, versions, commands, modes, exit codes, status, and finding counts), sanitized scanner reports, and the comparison outputs (`comparison.csv`, `comparison.json`, and `summary.md`).

Raw scanner reports are temporary and deleted after sanitization. Permanent files omit matched values and source-line contents. Run the wrappers in `scanners/` to replace the current report.
