import pathlib,json,struct,subprocess,bisect
root=pathlib.Path(__file__).parent;data=pathlib.Path('/tmp/arclake-arc-arm64.macho').read_bytes()
ncmds=struct.unpack_from('<I',data,16)[0];p=32
for _ in range(ncmds):
 cmd,size=struct.unpack_from('<II',data,p)
 if cmd==0x26: off,sz=struct.unpack_from('<II',data,p+8)
 p+=size
p=off;end=off+sz;addr=0x100000000;starts=[]
while p<end:
 val=0;shift=0
 while True:
  b=data[p];p+=1;val|=(b&127)<<shift;shift+=7
  if not b&128:break
 if val==0:break
 addr+=val;starts.append(addr)
meta=json.loads((root/'methods.json').read_text());manifest=json.loads((root.parent/'feature-manifest.json').read_text());menu=json.loads((root.parent/'menu-items.json').read_text())
ids={i for f in manifest for i in f['menus']};wanted={a for m in menu['items'] if m['id'] in ids for a in m['actions']}
selected=[m for m in meta['menu_methods'] if m['selector'] in wanted and m['class'] in ['_TtC3Arc20MainWindowController','_TtC3Arc19LittleBrowserWindow','_TtC3Arc13BrowserWindow','_TtC3Arc11AppDelegate']]
(root/'assembly').mkdir(exist_ok=True);results=[]
for m in selected:
 start=int(m['implementation'],16);i=bisect.bisect_left(starts,start)
 if i==len(starts) or starts[i]!=start:results.append({**m,'status':'not-in-function-starts'});continue
 end=starts[i+1];stop=min(end,start+16384)
 filename=m['class']+'--'+m['selector'].replace(':','')+'.asm'
 cmd=['xcrun','llvm-objdump','--disassemble','--start-address='+hex(start),'--stop-address='+hex(stop),'/tmp/arclake-arc-arm64.macho']
 r=subprocess.run(cmd,capture_output=True,text=True,check=True)
 (root/'assembly'/filename).write_text(r.stdout)
 results.append({**m,'status':'disassembled','end_exclusive':hex(end),'truncated':stop<end,'assembly_file':'assembly/'+filename,'command':cmd})
(root/'method-assembly-index.json').write_text(json.dumps({'authority':'supplementary-LLVM-static-disassembly','function_start_count':len(starts),'methods':results},ensure_ascii=False,indent=2))
print('Function starts:',len(starts),'selected methods:',len(results),'truncated:',sum(m.get('truncated',False) for m in results))
