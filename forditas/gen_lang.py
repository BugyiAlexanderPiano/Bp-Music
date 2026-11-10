import json, re, sys, os
HERE=os.path.dirname(os.path.abspath(__file__))
tpl = json.load(open(os.path.join(HERE,'forrasszovegek.json'), encoding='utf-8'))
names = {'tr':'trTable'}
ph = re.compile(r'\{\d+\}')
def gen(lang):
    lines = open(os.path.join(HERE,'forditasok',f'{lang}.txt'), encoding='utf-8').read().split('\n')
    if lines and lines[-1] == '': lines = lines[:-1]
    assert len(lines) == len(tpl), f'{lang}: {len(lines)} sor, {len(tpl)} kell'
    out = [f'// {lang} fordítás — kulcs: a magyar forrásszöveg (automatikusan generálva: tools/gen_lang.py)',
           f'const Map<String, String> {names.get(lang, lang)} = {{']
    bad = 0
    for i, (src, t) in enumerate(zip(tpl, lines)):
        t = t.strip()
        lead = src[:len(src) - len(src.lstrip())]; trail = src[len(src.rstrip()):]
        t = lead + t + trail
        if sorted(ph.findall(src)) != sorted(ph.findall(t)) or src.count('\\n') != t.count('\\n'):
            print(f'{lang} #{i}: helyőrző/sortörés eltér: {src!r} -> {t!r}'); bad += 1
        esc = lambda s: s.replace("'", "\\'").replace('$', '\\$')
        out.append(f"  '{esc(src)}': '{esc(t)}',")
    out.append('};\n')
    open(os.path.join(HERE,'..','flutter_app','lib','i18n','lang',f'{lang}.dart'), 'w', encoding='utf-8').write('\n'.join(out))
    return bad
langs = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(os.path.join(HERE,'forditasok')))
bad = sum(gen(l) for l in langs)
sys.exit(1 if bad else 0)
