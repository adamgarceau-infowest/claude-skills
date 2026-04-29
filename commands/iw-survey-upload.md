---
name: iw-survey-upload
description: "Upload InfoWest synthetic survey reports to the Google Drive surveys folder as formatted Google Docs — black table borders, bold header rows, cell padding. Accepts a list of markdown report paths or auto-detects recent survey files."
argument-hint: "[path/to/report.md ...] — omit to auto-detect all ~/iw-survey-report-*.md files"
---

# /iw-survey-upload — Upload Survey Reports to Google Drive

Convert InfoWest survey markdown reports to formatted Google Docs and upload them to the Drive surveys folder. Each doc gets:
- Black borders on every table
- Bold first row (column headers)
- Cell padding so text isn't squished
- Full-width tables

## Step 1: Detect Reports to Upload

1. **Inline arguments:** If file paths were provided after `/iw-survey-upload`, use those.
2. **Auto-detect:** Otherwise, find all survey reports in the home directory:
   ```bash
   ls -t ~/iw-survey-report-*.md ~/iw-survey-report-ptsd-*.md 2>/dev/null
   ```
   Exclude any file where all resonance scores are 0 (failed runs). Check by grepping for `0.0/10` — if every segment line has that, skip the file.
3. **Nothing found:** Tell the user: "No survey reports found. Run /iw-survey first."

Show the user the list of files that will be uploaded before proceeding.

---

## Step 2: Refresh Google Drive Token

The OAuth token expires every hour. Always refresh before uploading:

```bash
python3 << 'EOF'
import json, ssl, urllib.request, urllib.parse

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

with open('/Users/garceau/.config/google-drive-mcp/tokens.json') as f:
    tokens = json.load(f)
with open('/Users/garceau/.config/google-drive-mcp/gcp-oauth.keys.json') as f:
    keys = json.load(f)['installed']

data = urllib.parse.urlencode({
    'client_id': keys['client_id'],
    'client_secret': keys['client_secret'],
    'refresh_token': tokens['refresh_token'],
    'grant_type': 'refresh_token',
}).encode()
req = urllib.request.Request('https://oauth2.googleapis.com/token', data=data, method='POST')
resp = urllib.request.urlopen(req, context=ctx)
new_tokens = json.loads(resp.read())
tokens['access_token'] = new_tokens['access_token']
with open('/Users/garceau/.config/google-drive-mcp/tokens.json', 'w') as f:
    json.dump(tokens, f)
print(new_tokens['access_token'])
EOF
```

---

## Step 3: Delete Existing Files in Folder

Clear the surveys folder before uploading so there are no duplicates:

```python
folder_id = '1IZMybjosteoEy1xzx2Ws5S1CLg0lS4oM'

url = f'https://www.googleapis.com/drive/v3/files?q=%27{folder_id}%27+in+parents&fields=files(id,name)'
req = urllib.request.Request(url, headers={'Authorization': f'Bearer {access_token}'})
resp = urllib.request.urlopen(req, context=ctx)
existing = json.loads(resp.read())['files']
for f in existing:
    del_req = urllib.request.Request(
        f'https://www.googleapis.com/drive/v3/files/{f["id"]}',
        headers={'Authorization': f'Bearer {access_token}'}, method='DELETE')
    urllib.request.urlopen(del_req, context=ctx)
    print(f'Deleted: {f["name"]}')
```

---

## Step 4: Build Formatted .docx Files

For each markdown report, run this Python logic using `/Library/Frameworks/Python.framework/Versions/3.13/bin/python3`:

```python
import subprocess
from docx import Document
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

def format_tables(docx_path):
    doc = Document(docx_path)
    for table in doc.tables:
        tbl = table._tbl

        tblPr = tbl.find(qn('w:tblPr'))
        if tblPr is None:
            tblPr = OxmlElement('w:tblPr')
            tbl.insert(0, tblPr)

        # Black borders
        for old in tblPr.findall(qn('w:tblBorders')):
            tblPr.remove(old)
        tblBorders = OxmlElement('w:tblBorders')
        for side in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV'):
            el = OxmlElement(f'w:{side}')
            el.set(qn('w:val'), 'single')
            el.set(qn('w:sz'), '6')
            el.set(qn('w:space'), '0')
            el.set(qn('w:color'), '000000')
            tblBorders.append(el)
        tblPr.append(tblBorders)

        # Cell padding (108 twips ≈ 0.075 in)
        for old in tblPr.findall(qn('w:tblCellMar')):
            tblPr.remove(old)
        tblCellMar = OxmlElement('w:tblCellMar')
        for side in ('top', 'left', 'bottom', 'right'):
            el = OxmlElement(f'w:{side}')
            el.set(qn('w:w'), '108')
            el.set(qn('w:type'), 'dxa')
            tblCellMar.append(el)
        tblPr.append(tblCellMar)

        # Full-width table
        for old in tblPr.findall(qn('w:tblW')):
            tblPr.remove(old)
        tblW = OxmlElement('w:tblW')
        tblW.set(qn('w:w'), '9360')
        tblW.set(qn('w:type'), 'dxa')
        tblPr.append(tblW)

        # Bold first row
        if table.rows:
            for cell in table.rows[0].cells:
                for para in cell.paragraphs:
                    for run in para.runs:
                        run.bold = True
                    if para.text and not para.runs:
                        run = para.add_run(para.text)
                        run.bold = True
                        for child in list(para._p):
                            if child.tag != qn('w:r'):
                                para._p.remove(child)

    doc.save(docx_path)

# For each report file:
subprocess.run(['pandoc', md_path, '-o', docx_path], check=True)
format_tables(docx_path)
```

**Title format:** Derive the Google Doc title from the filename:
- `iw-survey-report-ptsd-20260411.md` → `IW Survey — Apr 11 2026 (Baseline)`
- `iw-survey-report-20260412-012645.md` → `IW Survey — Apr 12 2026 (SHIP IT 8.6/10)`
- `iw-survey-report-20260429.md` → `IW Survey — Apr 29 2026 (SHIP IT 7.57/10)`

For new files, read the weighted average resonance score from the report and include it in the title, e.g. `IW Survey — May 3 2026 (SHIP IT 7.8/10)`.

---

## Step 5: Upload to Google Drive as Google Docs

Upload each .docx as a Google Doc (Drive converts on ingest — preserves table formatting):

```python
DOCX_MIME = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
GDOC_MIME = 'application/vnd.google-apps.document'

boundary = 'iwboundary789'
meta = json.dumps({'name': title, 'parents': [folder_id], 'mimeType': GDOC_MIME}).encode()
body = (
    f'--{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'.encode()
    + meta + b'\r\n'
    + f'--{boundary}\r\nContent-Type: {DOCX_MIME}\r\n\r\n'.encode()
    + file_bytes + b'\r\n'
    + f'--{boundary}--'.encode()
)
req = urllib.request.Request(
    'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
    data=body,
    headers={
        'Authorization': f'Bearer {access_token}',
        'Content-Type': f'multipart/related; boundary={boundary}',
    },
    method='POST'
)
resp = urllib.request.urlopen(req, context=ctx)
result = json.loads(resp.read())
print(f'Uploaded: {title} → {result["id"]}')
```

---

## Step 6: Report Results

Print a summary:
```
Uploaded 3 survey reports to Google Drive (surveys folder):
  ✓ IW Survey — Apr 11 2026 (Baseline)
  ✓ IW Survey — Apr 12 2026 (SHIP IT 8.6/10)
  ✓ IW Survey — Apr 29 2026 (SHIP IT 7.57/10)
```

## Key Constants

- **Drive folder ID:** `1IZMybjosteoEy1xzx2Ws5S1CLg0lS4oM`
- **Token file:** `/Users/garceau/.config/google-drive-mcp/tokens.json`
- **OAuth keys:** `/Users/garceau/.config/google-drive-mcp/gcp-oauth.keys.json`
- **Python binary:** `/Library/Frameworks/Python.framework/Versions/3.13/bin/python3`
- **python-docx:** already installed on Python 3.13
