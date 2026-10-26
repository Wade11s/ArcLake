import pathlib,json,hashlib,datetime,re
for root in [pathlib.Path(__file__).resolve().parent,pathlib.Path(__file__).resolve().parent.parent]:
 files=[p for p in root.rglob('*') if p.is_file() and p.name!='checksums.json']
 (root/'checksums.json').write_text(json.dumps({'generated_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}},indent=2))
 missing=[]
 for p in root.glob('*.md'):
  for t in re.findall(r'\]\(([^)]+)\)',p.read_text()):
   if not t.startswith(('http:','https:','#')) and not (p.parent/t).exists():missing.append((str(p),t))
 assert not missing,missing
 print(root,'->',len(files),'files, links OK')
