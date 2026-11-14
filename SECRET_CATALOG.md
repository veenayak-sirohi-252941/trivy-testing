# Secret catalog overview

The authoritative, redacted catalog is `catalog/secret-file-catalog.json` and its CSV mirror. It covers application configuration and code, the preserved synthetic fixture project, additional root fixture assets, and supporting files. Each credential-like assignment or token occurrence receives a separate ID where its line can be distinguished.

The catalog stores only redacted references such as `SYNTHETIC_FIXTURE`, `PLACEHOLDER`, `POTENTIALLY_REAL`, or `REDACTED`; it never stores matched values. Filesystem findings and Git-history findings remain separate. A possibly real value is marked `POTENTIALLY_REAL` and requires owner review.

See `catalog/catalog-summary.md` for counts and `catalog/detection-matrix.csv` for current scanner statuses.
