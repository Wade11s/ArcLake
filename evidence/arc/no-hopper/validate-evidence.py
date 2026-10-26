import pathlib,json,struct,hashlib,re
root=pathlib.Path(__file__).parent
fat=pathlib.Path('/Applications/Arc.app/Contents/MacOS/Arc').read_bytes()
thin=pathlib.Path('/tmp/arclake-arc-arm64.macho').read_bytes()
assert struct.unpack_from('>I',fat)[0]==0xcafebabe
n=struct.unpack_from('>I',fat,4)[0]
for i in range(n):
 cpu,sub,offset,size,align=struct.unpack_from('>IIIII',fat,8+20*i)
 if cpu==0x100000c:break
else:raise AssertionError('arm64 slice absent')
assert fat[offset:offset+size]==thin
rea=json.loads((root/'rea-macho.json').read_text())
assert hashlib.sha256(fat).hexdigest()==rea['subject']['digest']['sha256']
m=json.loads((root/'methods.json').read_text());idx=json.loads((root/'method-assembly-index.json').read_text())
checked=0
for row in idx['methods']:
 if row['status']!='disassembled':continue
 for line in (root/row['assembly_file']).read_text().splitlines():
  match=re.match(r'([0-9a-f]+):\s+([0-9a-f]{8})\s',line)
  if not match:continue
  a=int(match[1],16);word=int(match[2],16)
  fileoff=row['implementation_file_offset']+a-int(row['implementation'],16)
  assert struct.unpack_from('<I',thin,fileoff)[0]==word
  checked+=1
result={'universal_sha256':hashlib.sha256(fat).hexdigest(),'arm64_sha256':hashlib.sha256(thin).hexdigest(),'arm64_slice_offset':offset,'arm64_slice_size':size,'slice_matches_original':True,'rea_identity_matches':True,'assembly_instructions_verified':checked,'method_count':len(m['methods']),'method_decode_error_count':len(m['decode_errors']),'swift_type_count':len(json.loads((root/'swift-fields.json').read_text())['types']),'note':'Byte identity/decoding checks, not runtime behavior or a formal proof of parser completeness.'}
(root/'validation.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
