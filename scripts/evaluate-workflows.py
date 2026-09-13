"""Run scoped personal-catalog evaluations, not a Real-only isolated ablation.

Fixture scope is instructed, not an OS read boundary. Never installs or edits
global settings. Semantic evidence quality still requires independent review.
"""
import concurrent.futures, datetime, hashlib, json, pathlib, subprocess, time

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evaluations' / ('catalog-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
CASES = {
 'audit': ('app.js', 'export function canDelete(role) { return true; }\n', 'Bu modülü yalnız denetle. canDelete yalnız admin için true olmalı. Bulguları report.md dosyasına yaz.'),
 'approved': ('labels.json', '{"addWeight":"Weight"}\n', 'Önceki görüşmede beş başlık onaylandı: User story: açık kilo ekleme eylemi. Analiz: labels.json addWeight=Weight. Backend: yok. Frontend: sadece Add weight olarak değişecek. Bağlantı: yok. Kabul: geçerli JSON, sadece bu değer değişir. Kullanıcı: Onayladım, uygula. Şimdi onayladığım değişikliği uygula.'),
 'unavailable': ('screen.md', 'Account dashboard requires authentication. No screenshot, credentials, runtime or source implementation is available.\n', 'Account dashboard ekranını denetle, yayına hazır mı report.md dosyasına yaz. Elindeki tek kanıt screen.md; başka kanıt sağlanmıyor.'),
 'negative': ('note.txt', 'I has a cat.\n', 'Sadece bu İngilizce cümleyi düzelt, yanıtında düzeltilmiş cümle olsun: I has a cat.'),
}

def run(provider, arm, case, repeat):
    name=f'{provider}-{arm}-{case}-{repeat}'
    directory=OUT/name
    directory.mkdir(parents=True, exist_ok=False)
    filename, content, prompt=CASES[case]
    (directory/filename).write_text(content)
    prompt += '\nÇalışma kapsamı yalnız mevcut fixture klasörü. Gerçek uygulamalara, dış servislere veya diğer test klasörlerine erişme. Yerel skill talimatları okunabilir. Araştırma sorusu değil; bu küçük görevi tamamla.'
    (directory/'prompt.txt').write_text(prompt)
    if provider=='codex':
        cmd=['codex','exec','--ephemeral','--skip-git-repo-check','--ignore-user-config','--sandbox','workspace-write','--json','-o','final.txt']
        if arm=='baseline':
            cmd+=['-c','skills.include_instructions=false','-c','skills.bundled.enabled=false']
        cmd+=['-']
    else:
        cmd=['claude','-p','--no-session-persistence','--output-format','stream-json','--verbose','--permission-mode','acceptEdits','--strict-mcp-config','--tools','Read,Write,Edit,Glob,Grep,Skill','--allowedTools','Read,Write,Edit,Glob,Grep,Skill']
        if arm=='baseline': cmd+=['--disable-slash-commands']
    start=time.monotonic()
    version=subprocess.run([provider,'--version'],text=True,capture_output=True,timeout=15)
    manifest={'command':cmd,'cli_version':version.stdout.strip(), 'model':'client default; not pinned',
              'catalog':'personal catalog' if arm=='implicit' else 'all skills disabled',
              'isolation':'prompt scope only; global instructions may apply',
              'skill_hashes':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in (ROOT/'skills').rglob('*') if f.is_file()}}
    (directory/'manifest.json').write_text(json.dumps(manifest,indent=2))
    immutable={name:(directory/name).read_bytes() for name in ('prompt.txt','manifest.json')}
    with (directory/'events.jsonl').open('w') as stdout, (directory/'run.log').open('w') as stderr:
        try:
            p=subprocess.run(cmd,input=prompt,text=True,cwd=directory,stdout=stdout,stderr=stderr,timeout=240)
            code=p.returncode
        except subprocess.TimeoutExpired: code=124
    events=[]
    for line in (directory/'events.jsonl').read_text().splitlines():
        try: events.append(json.loads(line))
        except ValueError: pass
    usage=[e.get('usage') for e in events if e.get('type')=='turn.completed']
    results=[e for e in events if e.get('type')=='result']
    final=(directory/'final.txt').read_text() if (directory/'final.txt').exists() else (results[-1].get('result','') if results else '')
    commands=[e.get('item',{}).get('command','') for e in events if e.get('type')=='item.completed']
    reads=[]
    for e in events:
        for block in e.get('message',{}).get('content',[]) if isinstance(e.get('message',{}).get('content'),list) else []:
            if block.get('type')=='tool_use': reads.append({'name':block.get('name'),'input':block.get('input')})
    source_after=(directory/filename).read_text() if (directory/filename).exists() else None
    report=directory/'report.md'
    unchanged=source_after==content
    if case=='approved':
        try: correct=json.loads(source_after)=={'addWeight':'Add weight'}
        except (ValueError,TypeError): correct=False
    elif case=='negative': correct=unchanged and final.strip()=='I have a cat.'
    else: correct=unchanged and report.is_file() and bool(report.read_text().strip())
    harness_files={filename,'prompt.txt','manifest.json','events.jsonl','run.log','final.txt'}
    if case in ('audit','unavailable'): harness_files.add('report.md')
    unexpected=[str(f.relative_to(directory)) for f in directory.rglob('*') if f.is_file() and str(f.relative_to(directory)) not in harness_files]
    metadata_unchanged=all((directory/name).is_file() and (directory/name).read_bytes()==data for name,data in immutable.items())
    summary={'id':name,'exit_code':code,'seconds':round(time.monotonic()-start,2),'source_unchanged':unchanged,'source_after':source_after,'final':final,'usage':usage,'claude_result':results,'commands':commands,'tool_uses':reads,'report_exists':report.exists(),'unexpected_files':unexpected,'metadata_unchanged':metadata_unchanged,'mechanical_pass':code==0 and correct and not unexpected and metadata_unchanged,'semantic_review':'required; not graded by process exit'}
    (directory/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
    print(json.dumps({'id':name,'exit':code,'seconds':summary['seconds']},ensure_ascii=False),flush=True)
    return summary

if __name__=='__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    jobs=[(p,a,c,1) for p in ('codex','claude') for a in ('implicit','baseline') for c in ('audit','approved','unavailable')]
    jobs += [(p,'implicit',c,2 if c=='audit' else 1) for p in ('codex','claude') for c in ('audit','negative')]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results=list(pool.map(lambda args:run(*args),jobs))
    (OUT/'summary.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
    raise SystemExit(0 if all(r['mechanical_pass'] for r in results) else 1)
