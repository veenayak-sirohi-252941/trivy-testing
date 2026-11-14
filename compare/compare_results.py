#!/usr/bin/env python3
"""Map sanitized scanner locations to catalog rows and create comparison reports."""
import argparse,csv,json,re
from collections import Counter,defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SCANNERS=('gitleaks','trufflehog','trivy')
EXPECTED_CLASSES={'SYNTHETIC_POSITIVE'}
NEGATIVE_CLASSES={'SYNTHETIC_NEGATIVE','PLACEHOLDER'}
STATUS_ORDER={'DETECTED':0,'NOT DETECTED':1,'FALSE POSITIVE':2,'UNEXPECTED FINDING':3,'NOT SUPPORTED':4,'NOT RUN':5,'EXECUTION ERROR':6,'INCONCLUSIVE':7,'REVIEW REQUIRED':8}

def read_json(p,default=None):
 try:return json.loads(p.read_text())
 except (OSError,json.JSONDecodeError):return default

def load_aliases():
 aliases={}
 p=ROOT/'compare/path-mapping.csv'
 if p.exists():
  for row in csv.DictReader(p.open()):
   old=row.get('original_path','');new=row.get('destination_path','')
   if new and not new.startswith('NOT_') and old!=new:aliases[old]=new
 return aliases

def normalize(path,aliases):
 p=str(path or '').replace('\\','/').lstrip('/')
 for old,new in sorted(aliases.items(),key=lambda x:-len(x[0])):
  if p==old:return new
  if p.startswith(old.rstrip('/')+'/'):return new.rstrip('/')+'/'+p[len(old.rstrip('/'))+1:]
 return p

def rule_category(f):
 text=' '.join(str(f.get(k,'')) for k in ('rule_id','detector','category')).lower()
 if any(x in text for x in ('aws','amazon')):return 'AWS credentials'
 if any(x in text for x in ('github','gitlab','pat')):return 'Source control credential'
 if any(x in text for x in ('postgres','mysql','mongo','jdbc','database','sql')):return 'Database credential'
 if any(x in text for x in ('jwt','session')):return 'Authentication token'
 if any(x in text for x in ('private-key','private key','ssh','pgp')):return 'Cryptographic material'
 if any(x in text for x in ('terraform','kubernetes','docker','registry','ansible')):return 'Infrastructure credential'
 if any(x in text for x in ('password','passwd')):return 'Password'
 if any(x in text for x in ('api','slack','stripe','bearer','token','secret','generic')):return 'API/application credential'
 return None

def pick_candidates(f, rows, aliases):
 path=normalize(f.get('file'),aliases); line=f.get('start_line')
 try:line=int(line)
 except (ValueError,TypeError):line=None
 candidates=[r for r in rows if normalize(r['file_path'],aliases)==path]
 if line is not None:
  exact=[r for r in candidates if int(r['line_number'])<=line<=int(r['line_number'])]
  if not exact:
   exact=[r for r in candidates if abs(int(r['line_number'])-line)<=1]
  candidates=exact
 category=rule_category(f)
 if category and len(candidates)>1:
  typed=[r for r in candidates if r['secret_category']==category or r['credential_type']==category]
  if typed:candidates=typed
 return path,line,candidates

def load_findings(run_dir,scanner,mode):
 p=run_dir/scanner/mode/'findings.redacted.json'
 data=read_json(p,{}) or {}
 return data.get('findings',[]),int(data.get('raw_findings',0))

def status_for_row(row, detected, scanner_status):
 if scanner_status=='NOT_RUN':return 'NOT RUN'
 if scanner_status=='EXECUTION_ERROR':return 'EXECUTION ERROR'
 hit=row['fixture_id'] in detected
 if row['classification'] in NEGATIVE_CLASSES:
  return 'FALSE POSITIVE' if hit else 'NOT DETECTED'
 if row['expected_detection']=='YES':return 'DETECTED' if hit else 'NOT DETECTED'
 return 'DETECTED' if hit else 'NOT DETECTED'

def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--run-dir',type=Path,required=True)
 ap.add_argument('--catalog',type=Path,default=ROOT/'catalog/secret-file-catalog.json')
 args=ap.parse_args(); run_dir=args.run_dir.resolve()
 metadata=read_json(run_dir/'metadata.json',{}) or {}
 rows=read_json(args.catalog,[])
 if not isinstance(rows,list):raise SystemExit('catalog JSON must be a list')
 aliases=load_aliases()
 all_map={}; raw_totals={}; statuses={}; unmatched={}; inconclusive={}; history={}
 for scanner in SCANNERS:
  run_records=[r for r in metadata.get('runs',[]) if r.get('scanner')==scanner]
  fs_record=next((r for r in run_records if r.get('mode')=='filesystem'),None)
  statuses[scanner]=('NOT_RUN' if not fs_record or fs_record.get('status')=='NOT_RUN' else 'EXECUTION_ERROR' if fs_record.get('status')=='EXECUTION_ERROR' else 'COMPLETED')
  findings,raw_total=load_findings(run_dir,scanner,'filesystem')
  raw_totals[scanner]=raw_total
  matched=set(); unmatched_rows=[]; inconclusive_rows=[]
  for finding in findings:
   path,line,candidates=pick_candidates(finding,rows,aliases)
   if len(candidates)==1:
    matched.add(candidates[0]['fixture_id'])
   elif len(candidates)>1:
    inconclusive_rows.append({'file':path,'line':line,'rule_id':finding.get('rule_id'),'candidate_fixture_ids':[r['fixture_id'] for r in candidates]})
   else:
    unmatched_rows.append({'file':path,'line':line,'rule_id':finding.get('rule_id'),'detector':finding.get('detector'),'classification':'UNEXPECTED FINDING'})
  all_map[scanner]=matched;unmatched[scanner]=unmatched_rows;inconclusive[scanner]=inconclusive_rows
  hf,hr=load_findings(run_dir,scanner,'git-history') if scanner in ('gitleaks','trufflehog') else ([],0)
  hm=set(); hu=0; hi=0
  for finding in hf:
   _,_,c=pick_candidates(finding,rows,aliases)
   if len(c)==1:hm.add(c[0]['fixture_id'])
   elif len(c)>1:hi+=1
   else:hu+=1
  history[scanner]={'raw_findings':hr,'mapped_fixture_ids':sorted(hm),'unmatched_findings':hu,'inconclusive_findings':hi}
 # Actual matrix. Preserve classification and path details; never include matched values.
 matrix=[]
 for row in rows:
  item=dict(row)
  for scanner in SCANNERS:item[scanner]=status_for_row(row,all_map[scanner],statuses[scanner])
  matrix.append(item)
  for scanner in SCANNERS:row[scanner]=item[scanner]
 (ROOT/'catalog/secret-file-catalog.json').write_text(json.dumps(rows,indent=2)+'\n')
 with (ROOT/'catalog/secret-file-catalog.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]) if rows else []);w.writeheader();w.writerows(rows)
 class_counts=Counter(r['classification'] for r in rows)
 cat_counts=Counter(r['secret_category'] for r in rows)
 summary=['# Catalog summary','','| Measure | Count |','|---|---:|',f"| Credential/fixture entries | {len(rows)} |",f"| Distinct source files | {len({r['file_path'] for r in rows})} |"]
 for name,count in sorted(class_counts.items()):summary.append(f'| {name} | {count} |')
 summary+=['','## Categories','']
 for name,count in sorted(cat_counts.items()):summary.append(f'- {name}: {count}')
 summary+=['','Values are withheld. `POTENTIALLY_REAL` and `UNCLASSIFIED` entries require owner review.']
 (ROOT/'catalog/catalog-summary.md').write_text('\n'.join(summary)+'\n')
 (ROOT/'catalog/detection-matrix.csv').parent.mkdir(exist_ok=True)
 cols=['fixture_id','file_path','line_number','secret_category','credential_type','classification','expected_detection',*SCANNERS]
 with (ROOT/'catalog/detection-matrix.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=cols);w.writeheader();w.writerows([{k:r.get(k,'') for k in cols} for r in matrix])
 metrics={}; positives={r['fixture_id'] for r in rows if r['classification'] in EXPECTED_CLASSES and r['expected_detection']=='YES'}
 for scanner in SCANNERS:
  det=all_map[scanner]&positives
  false={r['fixture_id'] for r in rows if r['classification'] in NEGATIVE_CLASSES and r['fixture_id'] in all_map[scanner]}
  errors=sum(x.get('scanner')==scanner and x.get('status')=='EXECUTION_ERROR' for x in metadata.get('runs',[]))
  metrics[scanner]={'raw_findings':raw_totals[scanner],'unique_fixtures_detected':len(det),'detected_fixture_ids':sorted(det),'expected_positive_fixtures':len(positives),'expected_fixtures_missed':len(positives-det) if statuses[scanner]=='COMPLETED' else None,'missed_fixture_ids':sorted(positives-det) if statuses[scanner]=='COMPLETED' else [],'negative_cases_reported':len(false),'false_positive_fixture_ids':sorted(false),'unexpected_findings':len(unmatched[scanner]),'inconclusive_findings':len(inconclusive[scanner]),'execution_errors':errors,'execution_status':statuses[scanner]}
 groups=defaultdict(list)
 for row in rows:
  if row['classification'] in EXPECTED_CLASSES and row['expected_detection']=='YES':groups[row['secret_category']].append(row['fixture_id'])
 categories={}
 for category,ids in sorted(groups.items()):
  categories[category]={s:{'detected':len(set(ids)&all_map[s]),'total':len(ids)} for s in SCANNERS}
 sets=[all_map[s]&positives for s in SCANNERS]
 overlap={'all_three':sorted(set.intersection(*sets) if sets else set()),'exactly_two':{},'only_gitleaks':sorted(sets[0]-sets[1]-sets[2]),'only_trufflehog':sorted(sets[1]-sets[0]-sets[2]),'only_trivy':sorted(sets[2]-sets[0]-sets[1]),'missed_by_all':sorted(positives-set.union(*sets))}
 for a,b in ((0,1),(0,2),(1,2)):
  overlap[f'{SCANNERS[a]}_and_{SCANNERS[b]}_only']=sorted((sets[a]&sets[b])-sets[3-a-b])
 result={'run_id':run_dir.name,'scanner_metrics':metrics,'category_metrics':categories,'detection_overlap':overlap,'unmatched_findings':unmatched,'inconclusive_findings':inconclusive,'git_history':history,'matrix':matrix}
 (run_dir/'comparison.json').write_text(json.dumps(result,indent=2)+'\n')
 with (run_dir/'comparison.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=cols);w.writeheader();w.writerows([{k:r.get(k,'') for k in cols} for r in matrix])
 lines=['# Scanner comparison', '',f"Run: `{run_dir.name}`",'', '| Metric | Gitleaks | TruffleHog | Trivy |','|---|---:|---:|---:|']
 for metric,label in [('raw_findings','Raw findings'),('unique_fixtures_detected','Unique positive fixtures mapped'),('expected_fixtures_missed','Expected positive fixtures missed'),('negative_cases_reported','Negative cases reported'),('unexpected_findings','Unmatched findings'),('inconclusive_findings','Inconclusive mappings'),('execution_errors','Execution errors')]:
  vals=[]
  for s in SCANNERS:
   v=metrics[s][metric];vals.append('NOT RUN' if v is None else str(v))
  lines.append(f'| {label} | {vals[0]} | {vals[1]} | {vals[2]} |')
 lines+=['','## Execution status','']
 for s in SCANNERS:lines.append(f"- {s}: {metrics[s]['execution_status']}; raw findings {raw_totals[s]}")
 lines+=['','## Missed positive fixtures','']
 for s in SCANNERS:
  miss=metrics[s]['missed_fixture_ids'];lines.append(f"- {s}: {', '.join(miss) if miss else ('not calculated' if metrics[s]['expected_fixtures_missed'] is None else 'none')}")
 lines+=['','## Negative cases flagged','']
 for s in SCANNERS:lines.append(f"- {s}: {', '.join(metrics[s]['false_positive_fixture_ids']) or 'none'}")
 lines+=['','## Shared and unique detections','',f"- All three: {', '.join(overlap['all_three']) or 'none'}",f"- Gitleaks only: {', '.join(overlap['only_gitleaks']) or 'none'}",f"- TruffleHog only: {', '.join(overlap['only_trufflehog']) or 'none'}",f"- Trivy only: {', '.join(overlap['only_trivy']) or 'none'}",f"- Missed by all: {', '.join(overlap['missed_by_all']) or 'none'}",'','## Git history scans','']
 for s,h in history.items():lines.append(f"- {s}: {h['raw_findings']} raw; {len(h['mapped_fixture_ids'])} fixture IDs mapped; {h['unmatched_findings']} unmatched; {h['inconclusive_findings']} inconclusive")
 lines+=['','## Findings requiring review','',f"- Potentially real catalog entries: {sum(r['classification']=='POTENTIALLY_REAL' for r in rows)}",f"- Unclassified catalog entries: {sum(r['classification']=='UNCLASSIFIED' for r in rows)}",'Values are withheld from this report. Review those source locations with their owners before treating them as fixtures.']
 (run_dir/'summary.md').write_text('\n'.join(lines)+'\n')
 print(f"comparison complete: {run_dir}")
 return 0
if __name__=='__main__':raise SystemExit(main())
