"""A build napló B64:<tag>:<adat> soraiból visszaállítja a képernyőképeket (shots/<tag>.png)."""
import base64, io, os, re, subprocess, sys
from PIL import Image
run = sys.argv[1]
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'shots'); os.makedirs(out, exist_ok=True)
log = subprocess.run(['gh', 'run', 'view', run, '--repo', 'BugyiAlexanderPiano/Bp-Music', '--log', '--job', sys.argv[2]],
                     capture_output=True, text=True).stdout
parts = {}
for line in log.splitlines():
    m = re.search(r'B64:([a-z]{2}_[a-z]+):(\S+)', line)
    if m: parts.setdefault(m.group(1), []).append(m.group(2))
for tag, chunks in parts.items():
    Image.open(io.BytesIO(base64.b64decode(''.join(chunks)))).save(os.path.join(out, tag + '.png'))
print(len(parts), sorted(parts))
