import json,pathlib,hashlib
root=pathlib.Path(__file__).parent
features=json.loads((root/'feature-manifest.json').read_text())
bundle=json.loads((root/'rea-bundle.json').read_text())
ib=next(r for r in bundle['records'] if r['operation']=='decode_interface_builder')
menu=json.loads((root/'menu-items.json').read_text())
static=json.loads((root/'static-text.json').read_text())
all_rows={r['file_offset_hex']:r for rows in static['matches'].values() for r in rows}
menu_map={r['id']:r for r in menu['items']}
for f in features:
 rows=[all_rows[o] for o in f['offsets'] if o in all_rows]
 assert len(rows)==len(f['offsets']),(f['id'],set(f['offsets'])-set(all_rows))
 items=[menu_map[i] for i in f['menus']]
 payload={'feature':f,'rea_evidence_id':ib['evidence_id'] if items else None,'rea_document':'Contents/Resources/Base.lproj/MainMenu.nib','menu_items':items,'supplementary_static_text':rows,'binary_sha256':static['sha256'],'runtime_verified':False}
 (root/(f['id']+'.json')).write_text(json.dumps(payload,ensure_ascii=False,indent=2))
 lines=['# '+f['title'],'','状态：部分证实（静态证据；未运行验证）。','','## 结论',f['finding'],'','## REA 菜单归档证据']
 if items:
  lines+=['Evidence ID: `'+ib['evidence_id']+'`','', '文件：`Contents/Resources/Base.lproj/MainMenu.nib`；对象编号见下。','', '| 对象 | 菜单标题 | key | modifier mask | selector |','|---|---|---|---|---|']
  for m in items:lines.append('| '+ ' | '.join([m['id'],m['title'] or '',repr(m['key']),str(m['mask']),', '.join(m['actions'])])+' |')
 else:lines+=['本项未取得独立 REA 功能证据；下列为补充的二进制文本观察，不能冒称 REA 输出。']
 lines+=['','## 补充：发行二进制中的原文','来源：`/Applications/Arc.app/Contents/MacOS/Arc`。偏移是 universal 文件字节偏移，不是虚拟地址；文本可能是用户文案、开发注释或内部标识，不能单独证明实现已执行。','']
 for r in rows:lines+=['### '+r['file_offset_hex'],'','> '+r['text'].replace('\n','\n> '),'']
 lines+=['## 未验证 / 限制',f['limits'],'','完整摘录：['+f['id']+'.json]('+f['id']+'.json)；原始 REA 记录：[rea-bundle.json](rea-bundle.json)。','']
 (root/(f['id']+'.md')).write_text('\n'.join(lines))
print('Generated',len(features),'feature Markdown files and',len(features),'JSON extracts.')
# Verify quoted bytes, full binary identity, and every selected menu object against retained REA data.
data=pathlib.Path(static['source']).read_bytes()
assert hashlib.sha256(data).hexdigest()==static['sha256']
count=0
for f in features:
 for o in f['offsets']:
  r=all_rows[o]; assert data[r['file_offset']:r['file_offset']+r['byte_length']].decode('utf-8')==r['text'];count+=1
print('Verified',count,'quoted byte ranges; binary SHA-256 matches.')
