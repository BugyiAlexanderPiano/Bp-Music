"""SoundNexus Pro feliratos videó-útmutató: content_<lang>.py + shots/<lang>_<id>.png → MP4 (1920×1080, 30 fps)."""
import importlib, os, subprocess, sys, textwrap
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 1920, 1080
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONTB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
ENC = ['-c:v', 'libx264', '-crf', '20', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', '-r', '30']


def gradient():
    g = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(g)
    a, b, c = (11, 16, 38), (29, 43, 100), (91, 42, 134)
    for x in range(W + H):
        t = x / (W + H)
        col = tuple(int((a[i] + (b[i] - a[i]) * t * 2) if t < .5 else (b[i] + (c[i] - b[i]) * (t - .5) * 2)) for i in range(3))
        d.line([(x, 0), (x - H, H)], fill=col, width=2)
    return g


BG = None


def frame(title, caption, shot, step=None):
    img = BG.copy()
    d = ImageDraw.Draw(img)
    # felső sáv: fejezetcím
    d.text((70, 38), title, font=ImageFont.truetype(FONTB, 46), fill=(255, 255, 255))
    if step:
        f = ImageFont.truetype(FONT, 28)
        d.text((W - 70 - d.textlength(step, font=f), 50), step, font=f, fill=(159, 216, 255))
    # képernyőkép középen
    top, bottom = 120, H - 210
    if shot and os.path.exists(shot):
        s = Image.open(shot).convert('RGB')
        sc = min((W - 140) / s.width, (bottom - top) / s.height)
        s = s.resize((int(s.width * sc), int(s.height * sc)), Image.LANCZOS)
        x, y = (W - s.width) // 2, top + (bottom - top - s.height) // 2
        sh = Image.new('RGBA', (s.width + 60, s.height + 60), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([30, 30, s.width + 30, s.height + 30], 18, fill=(0, 0, 0, 150))
        sh = sh.filter(ImageFilter.GaussianBlur(14))
        img.paste(sh, (x - 30, y - 20), sh)
        img.paste(s, (x, y))
    # felirat
    if caption:
        f = ImageFont.truetype(FONTB, 44)
        lines = textwrap.wrap(caption, 62)
        lh = 58
        bh = lh * len(lines) + 40
        by = H - 40 - bh
        ov = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(ov).rounded_rectangle([110, by, W - 110, by + bh], 22, fill=(8, 10, 24, 215))
        img = Image.alpha_composite(img.convert('RGBA'), ov).convert('RGB')
        d = ImageDraw.Draw(img)
        for i, ln in enumerate(lines):
            d.text(((W - d.textlength(ln, font=f)) / 2, by + 20 + i * lh), ln, font=f, fill=(255, 255, 255))
    return img


def title_card(big, small):
    img = BG.copy()
    d = ImageDraw.Draw(img)
    f1, f2 = ImageFont.truetype(FONTB, 96), ImageFont.truetype(FONT, 44)
    d.text(((W - d.textlength(big, font=f1)) / 2, 400), big, font=f1, fill=(255, 255, 255))
    for i, ln in enumerate(textwrap.wrap(small, 60)):
        d.text(((W - d.textlength(ln, font=f2)) / 2, 540 + i * 60), ln, font=f2, fill=(205, 220, 255))
    f3 = ImageFont.truetype(FONT, 30)
    t = 'Genos 2 · Genos · Tyros 5 · Tyros 4 · PSR-SX'
    d.text(((W - d.textlength(t, font=f3)) / 2, 720), t, font=f3, fill=(159, 216, 255))
    return img


def encode(png, dur, out, fade_in=True, fade_out=True):
    vf = 'format=yuv420p,loop=-1:1,trim=duration=%.2f' % dur
    if fade_in:
        vf += ',fade=t=in:st=0:d=0.4'
    if fade_out:
        vf += ',fade=t=out:st=%.2f:d=0.4' % (dur - 0.4)
    tmp = out[:-4] + '.tmp.mp4'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '30', '-i', png, '-vf', vf] + ENC + [tmp], check=True)
    os.replace(tmp, out)


def build(lang, only_frames=False):
    global BG
    BG = gradient()
    m = importlib.import_module(f'content_{lang}')
    meta, secs = m.META, m.SECTIONS
    work = os.path.join(HERE, 'video_work', lang)
    os.makedirs(work, exist_ok=True)
    scenes = []
    title_card(meta['title'], meta['intro_video']).save(f'{work}/s000.png')
    scenes.append((f'{work}/s000.png', 4.0, True, True))
    vsecs = [s for s in secs if s.get('video')]
    n = 0
    for k, s in enumerate(vsecs, 1):
        shot = os.path.join(HERE, 'shots', f'{lang}_{s["shot"]}.png') if s.get('shot') else None
        if not shot or not os.path.exists(shot):
            shot = os.path.join(HERE, 'shots', f'{lang}_main.png')
        for j, cap in enumerate(s['video']):
            n += 1
            p = f'{work}/s{n:03d}.png'
            frame(s['title'], cap, shot, f'{k} / {len(vsecs)}').save(p)
            dur = max(4.0, min(9.0, 1.6 + len(cap.split()) * 0.42))
            scenes.append((p, dur, j == 0, j == len(s['video']) - 1))
    n += 1
    title_card(meta['title'], meta['outro_video']).save(f'{work}/s{n:03d}.png')
    scenes.append((f'{work}/s{n:03d}.png', 5.0, True, True))
    if only_frames:
        return [sc[0] for sc in scenes]
    lst = []
    for i, (p, dur, fi, fo) in enumerate(scenes):
        out = p[:-4] + '.mp4'
        encode(p, dur, out, fi, fo)
        lst.append(f"file '{out}'")
    open(f'{work}/list.txt', 'w').write('\n'.join(lst))
    os.makedirs(os.path.join(HERE, 'out'), exist_ok=True)
    final = os.path.join(HERE, 'out', f'SoundNexusPro_{"Videoutmutato_HU" if lang == "hu" else "VideoGuide_EN"}.mp4')
    silent = f'{work}/video.mp4'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', f'{work}/list.txt', '-c', 'copy', silent], check=True)
    # néma hangsáv a lejátszók kompatibilitásáért
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', silent, '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo',
                    '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-shortest', '-movflags', '+faststart', final], check=True)
    print(final, sum(sc[1] for sc in scenes), 's')


if __name__ == '__main__':
    sys.path.insert(0, HERE)
    args = sys.argv[1:]
    frames = '--frames' in args
    for lang in [a for a in args if not a.startswith('--')] or ['hu', 'en']:
        r = build(lang, frames)
        if frames:
            print(r[:3])
