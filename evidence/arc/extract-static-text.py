#!/usr/bin/env python3
"""Supplementary byte observations, NOT REA Evidence or decompilation."""
import hashlib,json,re,pathlib
source=pathlib.Path('/Applications/Arc.app/Contents/MacOS/Arc')
data=source.read_bytes()
patterns={
 '01-sidebar':r'sidebar|address bar|navigation button',
 '02-spaces':r'space.{0,60}(theme|profile|switch|folder|pinned)|(?:theme|profile|switch|folder|pinned).{0,60}space',
 '03-profiles':r'profile.{0,120}(cookie|history|extension|space|sign|login)|(?:cookie|history|extension|space|sign|login).{0,120}profile',
 '04-favorites':r'favorite',
 '05-pinned-tabs':r'pinned.{0,100}(archiv|rename|folder|space)|(?:archiv|rename|folder|space).{0,100}pinned|pin tab',
 '06-folders':r'folder.{0,100}(shar|drag|pin|creat)|(?:shar|drag|pin|creat).{0,100}folder',
 '07-auto-archive':r'auto.?archiv|12 hours|twelveHours|archive.{0,80}(hour|day|never)|(?:hour|day).{0,80}archiv',
 '08-air-traffic-control':r'air.?traffic|link.{0,60}rout|rout.{0,60}link',
 '09-split-view':r'split.{0,80}(four|4|maximum|max|horizontal|vertical|pin|resiz)|(?:four|maximum|horizontal|vertical|resiz).{0,80}split|Split View',
 '10-little-arc':r'little.?arc|little.?browser|little.?window',
 '11-command-bar':r'command.?bar|omnibox.{0,80}(history|command|action|search)|(?:history|command|action|search).{0,80}omnibox',
}
compiled={k:re.compile(v,re.I) for k,v in patterns.items()}
matches={k:[] for k in patterns}
# NUL-delimited sequences; decode exact printable UTF-8 stretches, retain original offsets.
for m in re.finditer(rb'[^\x00-\x08\x0b-\x1f\x7f]{5,}',data):
 try:s=m.group().decode('utf-8')
 except UnicodeDecodeError:continue
 if len(s)>6000:continue
 for k,p in compiled.items():
  if p.search(s):matches[k].append({'file_offset':m.start(),'file_offset_hex':hex(m.start()),'byte_length':len(m.group()),'text':s})
out={'authority':'supplementary-local-byte-observation-not-REA','source':str(source),'sha256':hashlib.sha256(data).hexdigest(),'scope':'Whole universal binary; offsets are file offsets, not virtual addresses; CPU slice not attributed. Printable UTF-8 runs only. Strings do not establish execution or defaults.','patterns':patterns,'matches':matches}
pathlib.Path('evidence/arc/static-text.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
for k,rows in matches.items():
 print(k,len(rows))
 # Human-facing phrases first, then concise internal names.
 ranked=sorted(rows,key=lambda r:(' ' not in r['text'],len(r['text'])))
 seen=set()
 for r in ranked:
  if r['text'] in seen:continue
  seen.add(r['text']);print(r['file_offset_hex'],r['text'][:500])
  if len(seen)>=18:break
