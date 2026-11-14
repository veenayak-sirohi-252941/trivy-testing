#!/usr/bin/env python3
"""Validate catalog completeness, uniqueness, paths, and redaction markers."""
import csv,json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
JSON_PATH=ROOT/'catalog/secret-file-catalog.json'; CSV_PATH=ROOT/'catalog/secret-file-catalog.csv'
REQUIRED={'fixture_id','file_path','file_name','line_number','secret_category','credential_type','environment','classification','expected_detection','gitleaks','trufflehog','trivy','secret_reference','notes'}
SAFE={'REDACTED','SYNTHETIC_FIXTURE','PLACEHOLDER','POTENTIALLY_REAL','UNCLASSIFIED'}
ALLOWED={'SYNTHETIC_POSITIVE','SYNTHETIC_NEGATIVE','PLACEHOLDER','POTENTIALLY_REAL','UNCLASSIFIED'}
def main():
 try: data=json.loads(JSON_PATH.read_text())
 except Exception as e: print(f'ERROR catalog JSON: {type(e).__name__}'); return 1
 errors=[]; ids=[r.get('fixture_id') for r in data]
 if len(ids)!=len(set(ids)): errors.append('fixture IDs are not unique')
 for row in data:
  missing=REQUIRED-set(row)
  if missing: errors.append(f"{row.get('fixture_id')}: missing fields {sorted(missing)}")
  if row.get('classification') not in ALLOWED: errors.append(f"{row.get('fixture_id')}: unknown classification")
  if row.get('secret_reference') not in SAFE: errors.append(f"{row.get('fixture_id')}: secret_reference is not a safe redaction marker")
  p=ROOT/str(row.get('file_path',''))
  if not p.is_file(): errors.append(f"{row.get('fixture_id')}: catalog path missing: {row.get('file_path')}")
  try:
   line=int(row.get('line_number'))
   if line<1: raise ValueError()
  except (ValueError,TypeError): errors.append(f"{row.get('fixture_id')}: invalid line number")
 try:
  with CSV_PATH.open(newline='') as f: csv_rows=list(csv.DictReader(f))
  csv_pairs={(r.get('fixture_id'),r.get('file_path'),r.get('line_number')) for r in csv_rows}
  json_pairs={(str(r.get('fixture_id')),str(r.get('file_path')),str(r.get('line_number'))) for r in data}
  if csv_pairs!=json_pairs: errors.append('CSV and JSON entries differ')
 except Exception as e: errors.append(f'CSV read failed: {type(e).__name__}')
 if errors:
  for e in errors[:30]: print('ERROR:',e)
  print(f'catalog validation failed: {len(errors)} issue(s)'); return 1
 print(f'catalog valid: {len(data)} unique entries, values redacted, CSV/JSON match')
 return 0
if __name__=='__main__':raise SystemExit(main())
