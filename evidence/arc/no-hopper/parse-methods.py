"""Supplementary static Mach-O parsing, not REA output. No target execution."""
import struct,json,re,hashlib,pathlib
root=pathlib.Path(__file__).parent
data=pathlib.Path('/tmp/arclake-arc-arm64.macho').read_bytes()
assert struct.unpack_from('<I',data)[0]==0xfeedfacf
ncmds=struct.unpack_from('<I',data,16)[0]; pos=32;segs=[];sections=[]
for _ in range(ncmds):
 cmd,size=struct.unpack_from('<II',data,pos)
 if cmd==0x19:
  name=data[pos+8:pos+24].split(b'\0')[0].decode()
  vm,vs,fo,fs=struct.unpack_from('<QQQQ',data,pos+24);segs.append((name,vm,vs,fo,fs))
  ns=struct.unpack_from('<I',data,pos+64)[0]
  for i in range(ns):
   s=pos+72+80*i;sn=data[s:s+16].split(b'\0')[0].decode();addr,sz=struct.unpack_from('<QQ',data,s+32);off=struct.unpack_from('<I',data,s+48)[0]
   sections.append({'segment':name,'name':sn,'address':hex(addr),'size':sz,'file_offset':off})
 if cmd==0x80000034: fixups_offset,fixups_size=struct.unpack_from('<II',data,pos+8)
 pos+=size
def offset(a):
 for _,vm,vs,fo,fs in segs:
  if vm<=a<vm+fs:return fo+a-vm
 raise ValueError(hex(a))
def u64(a):return struct.unpack_from('<Q',data,offset(a))[0]
# Walk actual chained fixup slots; never decode arbitrary integers as pointers.
base_vm=next(vm for name,vm,vs,fo,fs in segs if name=='__TEXT')
starts=fixups_offset+struct.unpack_from('<I',data,fixups_offset+4)[0]
segcount=struct.unpack_from('<I',data,starts)[0];fixups={};chain_formats=[]
for si in range(segcount):
 rel=struct.unpack_from('<I',data,starts+4+4*si)[0]
 if not rel:continue
 loc=starts+rel
 size,page_size,fmt,segoff,maxvalid,pagecount=struct.unpack_from('<IHHQIH',data,loc)
 chain_formats.append({'segment_index':si,'format':fmt,'page_count':pagecount})
 if fmt not in (2,6):raise ValueError('Unsupported chained pointer format '+str(fmt))
 for pg in range(pagecount):
  start=struct.unpack_from('<H',data,loc+22+pg*2)[0]
  if start==0xffff:continue
  if start&0x8000:raise ValueError('multi-start unsupported')
  slot=base_vm+segoff+pg*page_size+start
  while True:
   raw=u64(slot);bind=raw>>63;nxt=(raw>>51)&0xfff
   if not bind:
    target=(raw&((1<<36)-1))|(((raw>>36)&0xff)<<56)
    fixups[slot]=target+(base_vm if fmt==6 else 0)
   if not nxt:break
   slot+=nxt*4
def pointer(a):
 if a not in fixups:raise ValueError('No verified rebase fixup for '+hex(a))
 return fixups[a]
def string(a):
 o=offset(a);end=data.index(b'\0',o,min(o+4096,len(data)));return data[o:end].decode('utf8')
methods=[];classes=[];errors=[];owner=None
# Only top-level class/meta-class name and baseMethods: protocol requirements excluded.
for lineno,line in enumerate((root/'objc-arm64.txt').read_text().splitlines(),1):
 m=re.match(r'^        name\s+(0x[0-9a-f]+) (.+)$',line)
 if m:owner=m[2];classes.append(owner)
 m=re.match(r'^        baseMethods\s+(0x[0-9a-f]+)',line)
 if not m or int(m[1],16)==0:continue
 base=int(m[1],16);o=offset(base);flags,count=struct.unpack_from('<II',data,o);stride=flags&0xffff
 if count>10000 or stride not in [12,24]:errors.append({'base':hex(base),'flags':hex(flags),'count':count});continue
 for i in range(count):
  p=base+8+i*stride
  try:
   if flags&0x80000000:
    nr,tr,ir=struct.unpack_from('<iii',data,offset(p));np=p+nr
    raw=pointer(np) if not flags&0x40000000 else np
    selector=string(raw);types=string(p+4+tr);imp=p+8+ir
   else:
    raw,tp,imp=pointer(p),pointer(p+8),pointer(p+16);selector=string(raw);types=string(tp)
   methods.append({'class':owner,'selector':selector,'implementation':hex(imp),'implementation_file_offset':offset(imp),'method_record_address':hex(p),'selector_pointer':hex(raw),'type_encoding':types,'metadata_line':lineno,'flags':hex(flags)})
  except (ValueError,UnicodeError,struct.error) as e:errors.append({'class':owner,'record':hex(p),'error':str(e)})
menus=json.loads((root.parent/'menu-items.json').read_text())
wanted={a for x in menus['items'] for a in x['actions']}
selected=[m for m in methods if m['selector'] in wanted]
output={'authority':'supplementary-static-macho','thin_sha256':hashlib.sha256(data).hexdigest(),'sections':sections,'chain_formats':chain_formats,'decoded_rebases':len(fixups),'classes':sorted(set(classes)),'methods':methods,'menu_methods':selected,'decode_errors':errors,'limitations':['Objective-C method lists only; Swift-only functions are not enumerated.','Metadata implementation address is not proof of runtime dispatch.','Only verified chain slots with pointer_format 2 or 6 are decoded; binds, multi-start pages and other formats are not guessed. Undecodable method records remain errors.']}
(root/'methods.json').write_text(json.dumps(output,ensure_ascii=False,indent=2))
print('classes',len(set(classes)),'methods',len(methods),'errors',len(errors),'menu bindings',len(selected))
for m in selected:print(m['class'],m['selector'],m['implementation'])
print('errors sample',errors[:3])
