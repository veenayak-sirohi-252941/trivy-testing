#!/usr/bin/env python3
"""Regenerate a run's markdown summary from its sanitized comparison JSON."""
import argparse,json
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('run_dir',type=Path);a=p.parse_args();d=a.run_dir.resolve()
 data=json.loads((d/'comparison.json').read_text()); names=('gitleaks','trufflehog','trivy'); metrics=data['scanner_metrics']
 lines=['# Secret scan comparison summary','',f"Run: `{data.get('run_id',d.name)}`",'','| Metric | Gitleaks | TruffleHog | Trivy |','|---|---:|---:|---:|']
 for key,label in [('raw_findings','Raw findings'),('unique_fixtures_detected','Unique positive fixtures mapped'),('expected_fixtures_missed','Expected fixtures missed'),('negative_cases_reported','Negative cases reported'),('unexpected_findings','Unmatched findings'),('inconclusive_findings','Inconclusive mappings'),('execution_errors','Execution errors')]:
  vals=['NOT RUN' if metrics[n][key] is None else str(metrics[n][key]) for n in names]
  lines.append(f'| {label} | {vals[0]} | {vals[1]} | {vals[2]} |')
 lines+=['','## Misses','']
 for n in names:lines.append(f"- {n}: {', '.join(metrics[n]['missed_fixture_ids']) if metrics[n]['missed_fixture_ids'] else ('not calculated' if metrics[n]['expected_fixtures_missed'] is None else 'none')}")
 lines+=['','## False positives','']
 for n in names:lines.append(f"- {n}: {', '.join(metrics[n]['false_positive_fixture_ids']) or 'none'}")
 lines+=['','## History scans','']
 for n,h in data.get('git_history',{}).items():lines.append(f"- {n}: {h['raw_findings']} raw, {len(h['mapped_fixture_ids'])} mapped, {h['unmatched_findings']} unmatched, {h['inconclusive_findings']} inconclusive")
 (d/'summary.md').write_text('\n'.join(lines)+'\n'); print(d/'summary.md');return 0
if __name__=='__main__':raise SystemExit(main())
