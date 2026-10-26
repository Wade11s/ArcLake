import json,pathlib,re,datetime
root=pathlib.Path(__file__).parent
cfg=json.loads((root/'feature-updates.json').read_text())
old={f['id']:f for f in json.loads((root.parent/'feature-manifest.json').read_text())}
types=json.loads((root/'swift-fields.json').read_text())['types'];tm={t['name']:t for t in types}
methods=json.loads((root/'method-assembly-index.json').read_text())['methods']
menus=json.loads((root.parent/'menu-items.json').read_text())['items']
docs=[]
(root/'official-docs').mkdir(exist_ok=True)
for file in ['docs-organize.json','docs-core.json','docs-release-notes.json']:
 j=json.loads((root/file).read_text())
 for r in j.get('results',[]):
  aid=re.search(r'/articles/(\d+)',r['url'])
  if not aid:continue
  name=aid[1]+'.md'
  (root/'official-docs'/name).write_text('# '+r['title']+'\n\nSource: '+r['url']+'\n\n'+r['text'])
  docs.append({**r,'saved_file':'official-docs/'+name})
for f in cfg:
 missing=[n for n in f['types'] if n not in tm];assert not missing,missing
 fs=[tm[n] for n in f['types']]
 ids=set(old[f['id']]['menus']);sels={a for m in menus if m['id'] in ids for a in m['actions']}
 ms=[m for m in methods if m['selector'] in sels]
 quotes=[]
 for d in docs:
  heading=''
  for line_no,line in enumerate(d['text'].splitlines(),1):
   if line.startswith('#'):heading=line
   if not line.strip() or line.startswith('#') or not any(p.casefold() in line.casefold() for p in f['docPatterns']):continue
   quotes.append({'source':d['url'],'title':d['title'],'section':heading,'source_text_line':line_no,'text':line,'saved_file':d['saved_file']})
 quotes.sort(key=lambda q: min(i for i,p in enumerate(f['docPatterns']) if p.casefold() in q['text'].casefold()))
 quotes=quotes[:12]
 payload={**f,'static_types':fs,'method_bodies':ms,'official_excerpts':quotes,'runtime_verified':False,'rea_macho_evidence':'ev_780f75cfcf14debdafbfe9e1804e72b246ee98aec3b9d598bd724a307a89fd1f','note':'Reflection/method parsing and LLVM assembly are supplementary local evidence, not REA observations. Official excerpts describe product contracts/history, not local execution.'}
 (root/(f['id']+'.json')).write_text(json.dumps(payload,ensure_ascii=False,indent=2))
 lines=['# '+old[f['id']]['title']]+['','**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**','','## 本轮结论',f['conclusion'],'','## Swift 静态结构','下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。','']
 for t in fs:
  lines+=['### `'+t['name']+'`','',t['kind']+' descriptor: `'+t['descriptor']+'`；field descriptor: `'+str(t['field_descriptor'])+'`','',', '.join('`'+x['name']+'`' for x in t['fields']) or '无字段记录','']
 lines+=['## 菜单 → 方法 → 机器码','']
 if ms:
  lines+=['| selector | 所属类型 | 实现地址 | 机器码 |','|---|---|---|---|']
  for m in ms:lines.append('| '+m['selector']+' | '+m['class']+' | '+m['implementation']+' | [assembly]('+m['assembly_file']+') |')
 else:lines+=['本项未选择直接菜单 selector；结构证据见上。没有据此声称完成了方法调用链验证。']
 lines+=['','## 官方文档/发布记录原文','历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。','']
 for q in quotes:
  lines+=['### '+q['title']+' — '+q['section'],'','[官方来源]('+q['source']+') / [已保存正文]('+q['saved_file']+')（抽取正文第 '+str(q['source_text_line'])+' 行）','', '> '+q['text'],'']
 if not quotes:lines+=['本轮没有为本项取得新的直接官方原文；保留上轮发行物文案证据。','']
 lines+=['## 残留未知',f['unknown'],'','[首轮证据](../'+f['id']+'.md) · [本轮完整 JSON]('+f['id']+'.json) · [总报告](README.md)']
 (root/(f['id']+'.md')).write_text('\n'.join(lines)+'\n')
print('Built 11 per-feature Markdown + JSON reports; saved',len(docs),'official documents.')
