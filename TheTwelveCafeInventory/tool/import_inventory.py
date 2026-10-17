"""One-time seed of the spreadsheet-derived JSON using Supabase service credentials.
Run from a secure administrator's computer only; never place service keys in Flutter.
"""
import json, os, pathlib, urllib.request, urllib.error
url=os.environ['SUPABASE_URL'].rstrip('/')+'/rest/v1/inventory_items?on_conflict=code'
key=os.environ['SUPABASE_SERVICE_ROLE_KEY']
data=json.loads((pathlib.Path(__file__).parents[1]/'data'/'initial_inventory.json').read_text())
rows=[{k:v for k,v in x.items() if k not in ('source_row',) or v is not None} for x in data]
for pos in range(0,len(rows),50):
 payload=json.dumps(rows[pos:pos+50]).encode()
 req=urllib.request.Request(url,data=payload,method='POST',headers={'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json','Prefer':'resolution=ignore-duplicates,return=minimal'})
 try:
  with urllib.request.urlopen(req,timeout=30) as response: print('Imported',pos,'status',response.status)
 except urllib.error.HTTPError as e:
  print(e.read().decode());raise
print('Imported entries:',len(rows))
