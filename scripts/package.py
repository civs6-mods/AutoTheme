from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import subprocess,sys,json
r=Path(__file__).resolve().parents[1];subprocess.run([sys.executable,str(r/'scripts/verify.py')],check=True)
version=json.loads((r/'release-manifest.json').read_text())['version']
out=r/f'dist/AutoTheme-{version}.zip';out.parent.mkdir(exist_ok=True)
with ZipFile(out,'w',ZIP_DEFLATED) as z:
 for p in sorted((r/'mod').iterdir()):
  if p.is_file():z.write(p,'AutoTheme/'+p.name)
 for n in ['README.md','README.zh-CN.md','LICENSE']:z.write(r/n,n)
 for p in sorted((r/'docs').glob('*.md')):z.write(p,'docs/'+p.name)
with ZipFile(out) as z:assert z.testzip() is None
print(out)
