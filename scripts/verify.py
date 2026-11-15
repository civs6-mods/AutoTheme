from pathlib import Path
import json,hashlib,xml.etree.ElementTree as ET
r=Path(__file__).resolve().parents[1];m=json.loads((r/'release-manifest.json').read_text())
actual={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((r/'mod').iterdir()) if p.is_file()}
assert actual==m['files'],'Release content differs from recorded hashes'
xml=ET.parse(r/'mod/AutoTheme.modinfo').getroot()
assert xml.get('id')==m['modId'] and int(xml.get('version'))==m['manifestVersion']
for p in (r/'mod').glob('*.xml'):ET.parse(p)
for x in xml.findall('./Files/File'):assert (r/'mod'/x.text).is_file(),x.text
print('Verified',len(actual),'release files, hashes, XML and mod manifest')
