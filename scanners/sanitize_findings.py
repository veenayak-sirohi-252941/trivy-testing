#!/usr/bin/env python3
"""Emit location and detector metadata only; never copy matched values."""
import json, sys
from pathlib import Path
scanner, mode, raw_name, output_name = sys.argv[1:5]
raw, output = Path(raw_name), Path(output_name)
records = []
def rel(value):
    value = str(value or '').replace('\\', '/')
    return value[len('/repo/'):] if value.startswith('/repo/') else value.lstrip('/')
if scanner == 'trufflehog':
    for line in raw.read_text(errors='replace').splitlines():
        try: item=json.loads(line)
        except json.JSONDecodeError: continue
        if not isinstance(item,dict) or not item.get('DetectorName'): continue
        data=item.get('SourceMetadata',{}).get('Data',{})
        src_type='Git' if 'Git' in data else 'Filesystem'
        src=data.get(src_type,{})
        records.append({'scanner':scanner,'mode':mode,'file':rel(src.get('file')),'start_line':src.get('line'),'end_line':src.get('line'),'rule_id':str(item.get('DetectorType','')),'detector':str(item.get('DetectorName','')),'category':str(item.get('DetectorName','')),'verified':bool(item.get('Verified')),'redacted':True})
elif scanner == 'gitleaks':
    data=json.loads(raw.read_text(errors='replace') or '[]')
    for item in data if isinstance(data,list) else []:
        records.append({'scanner':scanner,'mode':mode,'file':rel(item.get('File')),'start_line':item.get('StartLine'),'end_line':item.get('EndLine'),'rule_id':str(item.get('RuleID','')),'detector':str(item.get('Description','')),'category':str(item.get('RuleID','')),'redacted':True})
elif scanner == 'trivy':
    data=json.loads(raw.read_text(errors='replace') or '{}')
    for result in data.get('Results') or []:
        for item in result.get('Secrets') or []:
            records.append({'scanner':scanner,'mode':mode,'file':rel(result.get('Target')),'start_line':item.get('StartLine'),'end_line':item.get('EndLine'),'rule_id':str(item.get('RuleID','')),'detector':str(item.get('Title','')),'category':str(item.get('Category','')),'severity':item.get('Severity'),'redacted':True})
output.write_text(json.dumps({'scanner':scanner,'mode':mode,'raw_findings':len(records),'findings':records},indent=2)+'\n')
output.chmod(0o600)
raw.unlink(missing_ok=True)
