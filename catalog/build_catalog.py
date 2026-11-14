#!/usr/bin/env python3
"""Build redacted catalog rows from known fixtures and credential-like source lines."""
import csv,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FIELDS=['fixture_id','file_path','file_name','line_number','secret_category','credential_type','environment','classification','expected_detection','gitleaks','trufflehog','trivy','secret_reference','notes']
KEY_RE=re.compile(r'''(?ix)(?P<key>[A-Z0-9_.-]*(?:password|passwd|secret|token|api[_-]?key|access[_-]?key|auth[_-]?token|authorization|private[_-]?key|credential|personal[_-]?access[_-]?token|github[_-]?pat|pat[_-]?token|database[_-]?url|datasource[_-]?url|jwt)[A-Z0-9_.-]*)["']?\s*[:=]\s*["']?(?P<value>[^\s,"'}`]+)''')
URL_RE=re.compile(r'(?i)\b(postgres(?:ql)?|mysql|mongodb(?:\+srv)?)://([^\s:@/]+):([^\s@/]+)@[^\s/]+')
AWS_RE=re.compile(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b')
GITHUB_RE=re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{30,255}|github_pat_[A-Za-z0-9_]{30,255})\b')
JWT_RE=re.compile(r'\beyJ[A-Za-z0-9_-]{4,}\.eyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\b')
KEYBLOCK_RE=re.compile(r'-----BEGIN (?:OPENSSH PRIVATE KEY|RSA PRIVATE KEY|PGP PRIVATE KEY BLOCK|PRIVATE KEY)-----')
PLACEHOLDER_RE=re.compile(r'(?i)(?:\$\{[^}]+\}|\$\([^)]+\)|your[_ -]?[a-z0-9_-]*|replace[_ -]?with|synthetic|fixture|placeholder|example|changeme|dummy|test[_ -]?(?:password|token|secret|key))')

def env_for(path):
 p=path.lower()
 for env in ('prod','preprod','staging','dev'):
  if f'/{env}/' in '/'+p or p.startswith(env+'/'): return env.upper()
 return 'TEST' if p.startswith('fixtures/') or p.startswith('fixtures-extra/') else 'UNCLASSIFIED'

def describe(key,value,path):
 k=key.lower(); p=path.lower()
 if 'aws' in k or value.startswith(('AKIA','ASIA')): return 'AWS credentials','AWS access or secret key','AWS'
 if 'github' in k or value.startswith(('ghp_','github_pat_','gho_','ghu_')): return 'Source control credential','GitHub token','GITHUB'
 if value.startswith('postgres'): return 'Database credential','PostgreSQL URI','DB'
 if value.startswith('mysql'): return 'Database credential','MySQL URI','MYSQL'
 if value.startswith('mongo'): return 'Database credential','MongoDB URI','MONGO'
 if 'jwt' in k or value.startswith('eyJ'): return 'Authentication token','JWT-shaped token','JWT'
 if 'private' in k or 'private key' in value.lower(): return 'Cryptographic material','Private key block','SSH'
 if 'terraform' in p or p.endswith(('.tf','.tfvars')): return 'Infrastructure credential','Terraform secret','TF'
 if 'k8s/' in p or 'kubernetes' in p: return 'Infrastructure credential','Kubernetes secret','K8S'
 if 'ansible' in p: return 'Infrastructure credential','Ansible credential','ANSIBLE'
 if 'registry' in k or 'docker' in p or 'compose' in p: return 'Infrastructure credential','Container credential','DOCKER'
 if 'password' in k or 'passwd' in k: return 'Password','Plain-text password assignment','PASS'
 if any(x in k for x in ('api','auth','token','secret','credential','bearer','authorization')): return 'API/application credential','API or authentication secret','API'
 return 'Application credential','Credential-like assignment','APP'

def main():
 known_path=ROOT/'fixtures/tests/fixtures/positive/fixture_catalog.json'
 known=json.loads(known_path.read_text()) if known_path.exists() else []
 rows=[]; used_ids=set(); candidate_rows=[]
 def add(fid,path,line,category,ctype,prefix,classification,notes):
  if fid in used_ids: return
  used_ids.add(fid); expected='NO' if classification in ('SYNTHETIC_NEGATIVE','PLACEHOLDER') else 'YES'
  rows.append({'fixture_id':fid,'file_path':path,'file_name':Path(path).name,'line_number':line,'secret_category':category,'credential_type':ctype,'environment':env_for(path),'classification':classification,'expected_detection':expected,'gitleaks':'NOT RUN','trufflehog':'NOT RUN','trivy':'NOT RUN','secret_reference':('PLACEHOLDER' if classification=='PLACEHOLDER' else 'SYNTHETIC_FIXTURE' if classification.startswith('SYNTHETIC') else 'POTENTIALLY_REAL' if classification=='POTENTIALLY_REAL' else 'REDACTED'),'notes':notes})
 # Resolve original positive fixture IDs to current value lines by nearby marker only.
 for item in known:
  rel='fixtures/'+item['path'].removeprefix('./')
  file=ROOT/rel
  lines=file.read_text(errors='replace').splitlines() if file.is_file() else []
  mark=next((i for i,l in enumerate(lines) if item['id'] in l),0)
  probe=range(max(0,mark-2),min(len(lines),mark+3))
  loc=next((i for i in probe if KEY_RE.search(lines[i]) or URL_RE.search(lines[i]) or AWS_RE.search(lines[i]) or GITHUB_RE.search(lines[i]) or JWT_RE.search(lines[i]) or KEYBLOCK_RE.search(lines[i])),mark)
  typ=str(item.get('type','synthetic fixture')); low=typ.lower()
  cat,ctype,prefix=describe(typ,'',rel)
  if low.startswith('aws'): cat,ctype,prefix='AWS credentials',typ,'AWS'
  elif low.startswith('github'): cat,ctype,prefix='Source control credential',typ,'GITHUB'
  elif low.startswith(('db','postgres','mysql','mongo')): cat,ctype,prefix='Database credential',typ,'DB'
  elif low.startswith('pass'): cat,ctype,prefix='Password',typ,'PASS'
  elif low.startswith('api'): cat,ctype,prefix='API/application credential',typ,'API'
  elif low.startswith('ssh'): cat,ctype,prefix='Cryptographic material',typ,'SSH'
  elif low.startswith('jwt'): cat,ctype,prefix='Authentication token',typ,'JWT'
  elif low.startswith('tf'): cat,ctype,prefix='Infrastructure credential',typ,'TF'
  elif low.startswith('k8s'): cat,ctype,prefix='Infrastructure credential',typ,'K8S'
  add(item['id'],rel,loc+1,cat,ctype,prefix,'SYNTHETIC_POSITIVE','Fixture ID from the preserved positive fixture catalog.')
 # One catalog record for each credential-like assignment or token occurrence.
 next_num={}
 for row in rows:
  m=re.match(r'^([A-Z]+)-(\d+)$',row['fixture_id'])
  if m: next_num[m.group(1)]=max(next_num.get(m.group(1),0),int(m.group(2)))
 files=[]
 for top in ('application','fixtures','fixtures-extra','misc'):
  base=ROOT/top
  if base.exists(): files.extend(p for p in base.rglob('*') if p.is_file() and not p.is_symlink())
 for file in sorted(files):
  rel=file.relative_to(ROOT).as_posix()
  try:
   if file.stat().st_size>4_000_000: continue
   text=file.read_text(encoding='utf-8')
  except (UnicodeError,OSError): continue
  for ln,line in enumerate(text.splitlines(),1):
   occurrences=[]
   for m in KEY_RE.finditer(line): occurrences.append((m.start('value'),m.end('value'),m.group('key'),m.group('value')))
   for regex,key in ((URL_RE,'database_url'),(AWS_RE,'aws_access_key_id'),(GITHUB_RE,'github_token'),(JWT_RE,'jwt_token'),(KEYBLOCK_RE,'private_key')):
    for m in regex.finditer(line):
     start,end=(m.start(),m.end()) if regex is not URL_RE else (m.start(),m.end())
     if not any(start<e and end>s for s,e,_,_ in occurrences): occurrences.append((start,end,key,m.group(0)))
   for start,end,key,value in occurrences:
    category,ctype,prefix=describe(key,value,rel)
    # Avoid values that only configure a dynamic environment lookup.
    is_placeholder=bool(PLACEHOLDER_RE.search(value)) or value.startswith(('os.getenv','os.environ','process.env','${','%'))
    if '/fixtures/negative/' in '/'+rel or rel.endswith('placeholders.env') or rel.endswith('placeholders.yaml'):
     classification='SYNTHETIC_NEGATIVE'; prefix='NEG'
    elif is_placeholder: classification='PLACEHOLDER'
    elif rel.startswith('fixtures/'):
     classification='SYNTHETIC_POSITIVE'
    elif rel.startswith('fixtures-extra/') and re.search(r'(?i)(fake|test|fixture|synthetic)',rel+' '+line): classification='SYNTHETIC_POSITIVE'
    elif rel.startswith('application/'): classification='POTENTIALLY_REAL'
    elif rel.startswith('fixtures-extra/') or rel.startswith('misc/'): classification='UNCLASSIFIED'
    else: classification='UNCLASSIFIED'
    # Reuse a nearby existing fixture ID once when its type and value line agree.
    candidate=None
    for existing in rows:
     if existing['file_path']==rel and abs(int(existing['line_number'])-ln)<=2 and existing['fixture_id'] not in candidate_rows:
      if existing['secret_category']==category or existing['fixture_id'].startswith(prefix+'-'):
       candidate=existing; break
    if candidate:
     candidate_rows.append(candidate['fixture_id'])
     if candidate['line_number']!=ln and not (KEY_RE.search(line) or URL_RE.search(line) or AWS_RE.search(line) or GITHUB_RE.search(line) or JWT_RE.search(line) or KEYBLOCK_RE.search(line)):
      candidate['line_number']=ln
     continue
    # Multiple different credentials on one line get separate IDs. IDs contain no secret material.
    next_num[prefix]=next_num.get(prefix,0)+1
    fid=f'{prefix}-{next_num[prefix]:03d}'
    add(fid,rel,ln,category,ctype,prefix,classification,'Discovered by static credential-pattern cataloging; matched value withheld.')
 rows.sort(key=lambda x:(x['file_path'],int(x['line_number']),x['fixture_id']))
 (ROOT/'catalog').mkdir(exist_ok=True)
 (ROOT/'catalog/secret-file-catalog.json').write_text(json.dumps(rows,indent=2)+'\n')
 with (ROOT/'catalog/secret-file-catalog.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=FIELDS);w.writeheader();w.writerows(rows)
 print(f'Cataloged {len(rows)} credential and negative-fixture entries across {len(set(r["file_path"] for r in rows))} files.')
if __name__=='__main__': main()
