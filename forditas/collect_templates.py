"""Minden tr('...') sablon + az adatként tárolt (katalógus) feliratok összegyűjtése."""
import re, sys, json, glob
import os
HERE=os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0,HERE)
from dartstr import scan
root=os.path.join(HERE,'..','flutter_app','lib')
tpls=set()
for f in glob.glob(root+'/**/*.dart', recursive=True):
    if '/i18n/' in f: continue
    src=open(f).read()
    for s,e,lit,raw in scan(src):
        if src[max(0,s-3):s]=='tr(':
            body = lit[1:-1]
            tpls.add(body)
    # interpolációban (${...}) lévő tr('...') hívások
    for m in re.finditer(r"tr\('((?:[^'\\$]|\\.)*)'", src):
        tpls.add(m.group(1))
# adat-feliratok
proj=open(root+'/model/project.dart').read()
for name in ['rhythmCatalog','bottomCatalog','panelNames','buttonShapeNames']:
    m=re.search(name+r'\s*=\s*(?:<[^>]*>)?\{(.*?)\};', proj, re.S)
    for v in re.findall(r":\s*'([^']*)'", m.group(1)): tpls.add(v)
for v in re.findall(r"VoiceGroup\('([^']*)'", proj): tpls.add(v)
for v in ["Bemutató projekt","Bemutató dal","Második dal","Bemutató dallam","Új projekt","Bank 1"]: tpls.add(v)
ed=open(root+'/ui/panel_editors.dart').read()
m=re.search(r"_categories = \{(.*?)\};", ed, re.S)
for v in re.findall(r":\s*'([^']*)'", m.group(1)): tpls.add(v)
dl=open(root+'/ui/dialogs.dart').read()
for v in re.findall(r"_Preset\('([^']*)'", dl): tpls.add(v)
tpls={t for t in tpls if t.strip()}
json.dump(sorted(tpls), open(os.path.join(HERE,'forrasszovegek.json'),'w'), ensure_ascii=False, indent=1)
print(len(tpls))
