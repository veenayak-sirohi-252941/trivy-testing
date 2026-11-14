#!/usr/bin/env python3
"""Map common JSON/JSONL scanner report paths to fixture IDs."""
import argparse, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ID = re.compile(r'\b(?:AWS|GITHUB|DB|PASS|API|SSH|JWT|TF|K8S|NEG)-\d{3}\b')

def objects(value):
    if isinstance(value, dict):
        yield value
        for v in value.values(): yield from objects(v)
    elif isinstance(value, list):
        for v in value: yield from objects(v)

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reports', nargs='*', type=Path)
    args = p.parse_args()
    if not args.reports: p.print_help(); return 0
    catalog = json.loads((ROOT / 'tests/fixtures/positive/fixture_catalog.json').read_text())
    expected = {item['id'] for item in catalog}
    negative_paths = {'tests/fixtures/negative/placeholders.env': 'NEG-001', 'tests/fixtures/negative/placeholders.yaml': 'NEG-002'}
    for report in args.reports:
        if not report.is_file(): print(f'NOT RUN: {report} unavailable'); continue
        raw = report.read_text(errors='replace')
        try: data = [json.loads(raw)]
        except json.JSONDecodeError:
            data = []
            for line in raw.splitlines():
                try: data.append(json.loads(line))
                except json.JSONDecodeError: pass
        ids, negative_hits, unmapped = set(), set(), 0
        for item in objects(data):
            nested = list(objects(item))
            path = next((obj[k] for obj in nested for k in ('File', 'file', 'file_path', 'path', 'Target') if isinstance(obj.get(k), str)), None)
            line_number = next((obj[k] for obj in nested for k in ('StartLine', 'LineNumber', 'line') if isinstance(obj.get(k), int)), None)
            if not path:
                continue
            if path.startswith('/repo/'):
                candidate = ROOT / path[len('/repo/'):]
            else:
                candidate = Path(path)
                if not candidate.is_absolute(): candidate = ROOT / candidate
            try:
                content = candidate.read_text(errors='ignore').splitlines()
                if line_number and 1 <= line_number <= len(content):
                    # Prefer an ID on the actual finding line. If the marker is
                    # on a nearby comment line, map only the closest marker.
                    indexes = range(max(0, line_number - 3), min(len(content), line_number + 2))
                    nearby = [(abs((idx + 1) - line_number), set(ID.findall(content[idx]))) for idx in indexes]
                    exact = [labels for distance, labels in nearby if distance == 0 and labels]
                    if exact:
                        found = set().union(*exact)
                    else:
                        nonempty = [(distance, labels) for distance, labels in nearby if labels]
                        nearest = min((distance for distance, _ in nonempty), default=None)
                        found = set().union(*(labels for distance, labels in nonempty if distance == nearest)) if nearest is not None else set()
                    ids.update(found & expected)
                    negative_hits.update(found - expected)
                    if not found and str(candidate).startswith(str(ROOT / 'tests/fixtures/negative')):
                        unmapped += 1
            except OSError:
                pass
        print(f'{report}: detected expected fixture IDs: {", ".join(sorted(ids)) or "none"}')
        print(f'  missed positive IDs: {", ".join(sorted(expected - ids)) or "none"}')
        print(f'  negative fixture findings (false-positive candidates): {", ".join(sorted(negative_hits)) or "none"}')
        if unmapped: print(f'  findings in negative paths without a nearby fixture ID: {unmapped}')
    return 0

if __name__ == '__main__': raise SystemExit(main())
