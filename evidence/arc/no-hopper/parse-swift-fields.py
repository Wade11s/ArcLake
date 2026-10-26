"""Swift nominal descriptors and field records, bounded read-only subset parser.
Relative pointers follow Swift ABI; symbolic field type references not decoded.
"""
import pathlib,struct,json,hashlib,re
root=pathlib.Path(__file__).parent
data=pathlib.Path('/tmp/arclake-arc-arm64.macho').read_bytes()
sections=json.loads((root/'methods.json').read_text())['sections']
def off(a):
 for s in sections:
  b=int(s['address'],16)
  if b<=a<b+s['size'] and s['file_offset']>0:return s['file_offset']+a-b
 raise ValueError('unmapped '+hex(a))
def u32(a):return struct.unpack_from('<I',data,off(a))[0]
def relative(a):
 v=struct.unpack_from('<i',data,off(a))[0]
 return a+v if v else None
def string(a):
 o=off(a);end=data.index(b'\0',o,min(o+2048,len(data)));return data[o:end].decode('utf8')
def name(a,depth=0):
 if a is None:return ''
 if depth>12:return '<depth-limit>'
 kind=u32(a)&31
 if kind not in (0,16,17,18):return '<context-kind-'+str(kind)+'>'
 n=string(relative(a+8));parent=relative(a+4)
 # Parent pointer low-bit indirect flag is not guessed.
 if parent and parent&1:return '<indirect-context>.'+n
 p=name(parent,depth+1)
 return p+'.'+n if p else n
types=[];errors=[]
sec=next(s for s in sections if s['name']=='__swift5_types')
for i in range(sec['size']//4):
 entry=int(sec['address'],16)+4*i
 try:
  a=relative(entry);kind=u32(a)&31
  if kind not in (16,17,18):continue
  n=name(a);f=relative(a+16);fields=[]
  if f:
   fo=off(f);fk,recordsize,count=struct.unpack_from('<HHI',data,fo+8)
   if recordsize!=12 or count>10000:raise ValueError('unsupported field records')
   for j in range(count):
    rec=f+16+j*recordsize;flags=u32(rec);np=relative(rec+8);tp=relative(rec+4)
    fields.append({'name':string(np),'flags':flags,'record_address':hex(rec),'type_reference_address':hex(tp) if tp else None})
  types.append({'name':n,'kind':{16:'class',17:'struct',18:'enum'}[kind],'descriptor':hex(a),'field_descriptor':hex(f) if f else None,'fields':fields})
 except (ValueError,UnicodeError,struct.error) as e:errors.append({'entry':hex(entry),'error':str(e)})
j={'authority':'supplementary-static-swift-reflection','thin_sha256':hashlib.sha256(data).hexdigest(),'types':types,'errors':errors,'limitations':['Only direct nominal type descriptors and 12-byte field records.','Names/field associations are static ABI declarations, not active state or observed behavior.','Symbolic field type references and indirect parent contexts are not resolved.']}
(root/'swift-fields.json').write_text(json.dumps(j,ensure_ascii=False,indent=2))
print('types',len(types),'errors',len(errors))
pat=re.compile(r'^(?:.*\.)?(?:Space|Profile|Sidebar|SplitView|LinkRouting|AutoArchive|Favorite|BrowserWindow|CommandBar)(?:Model|State|Item|Container|Rule|Route|Time|Inactive|Data|Pane|Configuration|Settings|Client|Action|Search|Candidate|Result|$)',re.I)
selected=[t for t in types if pat.search(t['name'])]
(root/'swift-fields-selected.json').write_text(json.dumps(selected,ensure_ascii=False,indent=2))
for t in selected: print(t['name'],t['descriptor'],','.join(f['name'] for f in t['fields'])[:800])
