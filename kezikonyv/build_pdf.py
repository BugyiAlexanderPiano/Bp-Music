"""SoundNexus Pro kézikönyv: tartalom (content_<lang>.py) + képernyőképek (shots/<lang>_<id>.png) → PDF."""
import base64, html, importlib, os, re, sys
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(HERE, 'shots')


def img_uri(path):
    if not os.path.exists(path):
        return None
    ext = 'jpeg' if path.endswith('.jpg') else 'png'
    return f'data:image/{ext};base64,' + base64.b64encode(open(path, 'rb').read()).decode()


def inline(s):
    s = html.escape(s, quote=False)
    return re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', s)


def render_body(text):
    out, in_list = [], False
    for line in text.strip().split('\n'):
        line = line.rstrip()
        if not line:
            continue
        is_item = line.startswith('- ')
        if in_list and not is_item:
            out.append('</ul>'); in_list = False
        if line.startswith('## '):
            out.append(f'<h3>{inline(line[3:])}</h3>')
        elif is_item:
            if not in_list:
                out.append('<ul>'); in_list = True
            out.append(f'<li>{inline(line[2:])}</li>')
        elif line.startswith('> '):
            out.append(f'<div class="tip">{inline(line[2:])}</div>')
        elif line.startswith('! '):
            out.append(f'<div class="warn">{inline(line[2:])}</div>')
        else:
            out.append(f'<p>{inline(line)}</p>')
    if in_list:
        out.append('</ul>')
    return '\n'.join(out)


CSS = '''
@page { size: A4; margin: 18mm 16mm 20mm 16mm; }
* { box-sizing: border-box; }
body { font-family: 'DejaVu Sans', 'Noto Sans', sans-serif; font-size: 10.3pt; line-height: 1.5; color: #1b1f2a; margin: 0; }
.cover { height: 257mm; display: flex; flex-direction: column; justify-content: space-between; padding: 14mm 12mm;
  background: linear-gradient(135deg, #0b1026 0%, #1d2b64 45%, #5b2a86 100%); color: #fff; border-radius: 6mm; page-break-after: always; }
.cover .brand { font-size: 11pt; letter-spacing: 3px; text-transform: uppercase; color: #9fd8ff; }
.cover h1 { font-size: 40pt; margin: 6mm 0 2mm; line-height: 1.1; }
.cover h2 { font-size: 17pt; font-weight: normal; margin: 0; color: #dfe6ff; }
.cover img { width: 100%; border-radius: 3mm; box-shadow: 0 4mm 12mm rgba(0,0,0,.45); }
.cover .models { font-size: 10pt; color: #cbd5ff; }
.toc { page-break-after: always; }
.toc h2 { font-size: 20pt; color: #1d2b64; border-bottom: 2px solid #5b2a86; padding-bottom: 2mm; }
.toc ol { columns: 1; padding-left: 6mm; font-size: 11pt; line-height: 2; }
.toc a { color: #1b1f2a; text-decoration: none; }
section { page-break-before: always; }
section h2 { font-size: 18pt; color: #1d2b64; margin: 0 0 4mm; padding-bottom: 2mm; border-bottom: 2px solid #5b2a86; }
section h2 .num { color: #5b2a86; margin-right: 3mm; }
h3 { break-after: avoid; font-size: 12pt; color: #5b2a86; margin: 5mm 0 1.5mm; }
p { margin: 0 0 2.5mm; }
ul { margin: 0 0 3mm; padding-left: 6mm; }
li { margin-bottom: 1.2mm; }
figure { margin: 2mm 0 5mm; page-break-inside: avoid; }
figure { text-align: center; }
figure img { max-width: 100%; max-height: 98mm; border: 1px solid #c9cfe0; border-radius: 2mm; }
figcaption { font-size: 8.8pt; color: #5d6478; margin-top: 1.5mm; text-align: center; }
.tip, .warn { padding: 2.5mm 4mm; border-radius: 2mm; margin: 3mm 0; page-break-inside: avoid; }
.tip { background: #eaf4ff; border-left: 4px solid #2f7de1; }
.warn { background: #fff4e5; border-left: 4px solid #e08a00; }
table { width: 100%; border-collapse: collapse; margin-top: 3mm; font-size: 9.8pt; }
td { border-bottom: 1px solid #d9deea; padding: 2mm 2.5mm; vertical-align: top; }
tr:nth-child(odd) td { background: #f5f6fb; }
td:first-child { width: 48%; }
td:last-child { font-weight: bold; color: #1d2b64; }
'''


def build(lang):
    m = importlib.import_module(f'content_{lang}')
    meta, secs = m.META, m.SECTIONS
    cover = img_uri(os.path.join(SHOTS, f'{lang}_main.png'))
    parts = [f'<html lang="{lang}"><head><meta charset="utf-8"><style>{CSS}</style></head><body>']
    parts.append('<div class="cover"><div><div class="brand">Yamaha Arranger Suite</div>'
                 f'<h1>{inline(meta["title"])}</h1><h2>{inline(meta["subtitle"])}</h2></div>'
                 + (f'<img src="{cover}">' if cover else '') +
                 f'<div class="models">Genos 2 · Genos · Tyros 5 · Tyros 4 · PSR-SX<br>{inline(meta["version"])}</div></div>')
    parts.append(f'<div class="toc"><h2>{inline(meta["toc"])}</h2><ol>')
    for s in secs:
        parts.append(f'<li><a href="#{s["id"]}">{inline(s["title"])}</a></li>')
    parts.append('</ol></div>')
    fig = 0
    for i, s in enumerate(secs, 1):
        parts.append(f'<section id="{s["id"]}"><h2><span class="num">{i}.</span>{inline(s["title"])}</h2>')
        shot = s.get('shot')
        uri = img_uri(os.path.join(SHOTS, f'{lang}_{shot}.png')) if shot else None
        if uri and s['id'] != 'intro':
            fig += 1
            parts.append(f'<figure><img src="{uri}"><figcaption>{fig}. {meta["fig"]} – {inline(s["title"])}</figcaption></figure>'
                         if lang == 'hu' else
                         f'<figure><img src="{uri}"><figcaption>{meta["fig"]} {fig} – {inline(s["title"])}</figcaption></figure>')
        parts.append(render_body(s['body']))
        if s.get('table'):
            parts.append('<table>' + ''.join(f'<tr><td>{inline(a)}</td><td>{inline(b)}</td></tr>' for a, b in s['table']) + '</table>')
        parts.append('</section>')
    parts.append('</body></html>')
    page_html = '\n'.join(parts)
    html_path = os.path.join(HERE, f'manual_{lang}.html')
    open(html_path, 'w', encoding='utf-8').write(page_html)
    out = os.path.join(HERE, 'out', f'SoundNexusPro_{"Kezikonyv_HU" if lang == "hu" else "Manual_EN"}.pdf')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    footer = ('<div style="width:100%;font-size:8px;color:#8a90a2;font-family:DejaVu Sans;padding:0 16mm;'
              'display:flex;justify-content:space-between"><span>SoundNexus Pro – ' + html.escape(meta['subtitle']) +
              '</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>')
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
        pg = b.new_page()
        pg.goto('file://' + html_path)
        pg.pdf(path=out, format='A4', print_background=True, display_header_footer=True,
               header_template='<div></div>', footer_template=footer,
               margin=dict(top='18mm', bottom='20mm', left='16mm', right='16mm'))
        b.close()
    print(out)


if __name__ == '__main__':
    sys.path.insert(0, HERE)
    for lang in sys.argv[1:] or ['hu', 'en']:
        build(lang)
