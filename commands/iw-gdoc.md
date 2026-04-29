---
name: iw-gdoc
description: "Convert any markdown content to a formatted Google Doc and upload to Drive. Black table borders, bold header rows, cell padding. Use this any time Adam asks to make a doc, create a Google doc, or save something to Drive."
argument-hint: "[title] -- omit to auto-generate title from content"
---

# /iw-gdoc — Create a Formatted Google Doc

Convert markdown content to a Google Doc with proper formatting and upload it to Google Drive.

**Use this skill any time Adam asks to:**
- "make this a Google doc"
- "create a doc from this"
- "save this to Drive"
- "put this in Drive"
- "turn this into a doc"

---

## Step 1: Detect Content

Find the content to convert using this priority order:

1. **Conversation context:** Use the most recently generated or discussed markdown content — a report, survey, plan, copy output, analysis, etc.
2. **File argument:** If a file path was passed after `/iw-gdoc`, read that file.
3. **Inline argument:** If text was passed directly, use that.
4. **Ask:** If nothing found, ask: "What content should I turn into a Google Doc?"

---

## Step 2: Determine Title and Folder

**Title:**
- If an argument was passed to the skill, use it as the title.
- Otherwise, infer a concise title from the content (e.g. first H1 heading, or a descriptive name).

**Folder:**
- Ask the user: "Which Drive folder? (Or just say root/my Drive)" unless they already specified.
- Known folder IDs:
  - Surveys: `1IZMybjosteoEy1xzx2Ws5S1CLg0lS4oM`
  - Root (My Drive): omit `parents` from the API call

---

## Step 3: Refresh Google Drive Token

Always refresh before uploading — tokens expire hourly:

```bash
/Library/Frameworks/Python.framework/Versions/3.13/bin/python3 << 'EOF'
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

## Step 4: Write Markdown to Temp File and Convert to .docx

```bash
# Write content to temp file
cat > /tmp/gdoc-content.md << 'MDEOF'
[CONTENT HERE]
MDEOF

# Convert with pandoc
pandoc /tmp/gdoc-content.md -o /tmp/gdoc-output.docx
```

---

## Step 5: Apply Table Formatting

Run this with `/Library/Frameworks/Python.framework/Versions/3.13/bin/python3`:

```python
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

        # Black borders on all sides and inner rules
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

        # Cell padding — 108 twips (~0.075 in) per side
        for old in tblPr.findall(qn('w:tblCellMar')):
            tblPr.remove(old)
        tblCellMar = OxmlElement('w:tblCellMar')
        for side in ('top', 'left', 'bottom', 'right'):
            el = OxmlElement(f'w:{side}')
            el.set(qn('w:w'), '108')
            el.set(qn('w:type'), 'dxa')
            tblCellMar.append(el)
        tblPr.append(tblCellMar)

        # Full page width
        for old in tblPr.findall(qn('w:tblW')):
            tblPr.remove(old)
        tblW = OxmlElement('w:tblW')
        tblW.set(qn('w:w'), '9360')
        tblW.set(qn('w:type'), 'dxa')
        tblPr.append(tblW)

        # Bold first row (column headers)
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

format_tables('/tmp/gdoc-output.docx')
```

---

## Step 6: Upload to Google Drive as Google Doc

```python
import json, ssl, urllib.request

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

with open('/Users/garceau/.config/google-drive-mcp/tokens.json') as f:
    tokens = json.load(f)
access_token = tokens['access_token']

DOCX_MIME = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
GDOC_MIME = 'application/vnd.google-apps.document'

with open('/tmp/gdoc-output.docx', 'rb') as f:
    file_bytes = f.read()

# Build metadata — include 'parents' only if uploading to a specific folder
meta = {'name': TITLE, 'mimeType': GDOC_MIME}
if FOLDER_ID:
    meta['parents'] = [FOLDER_ID]

boundary = 'iwboundary789'
meta_bytes = json.dumps(meta).encode()
body = (
    f'--{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'.encode()
    + meta_bytes + b'\r\n'
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
file_id = result['id']
print(f'Created: https://docs.google.com/document/d/{file_id}/edit')
```

---

## Step 7: Report Back

Tell the user:
```
Google Doc created: [Title]
https://docs.google.com/document/d/[ID]/edit
```

---

## Key Constants

- **Python binary:** `/Library/Frameworks/Python.framework/Versions/3.13/bin/python3`
- **Token file:** `/Users/garceau/.config/google-drive-mcp/tokens.json`
- **OAuth keys:** `/Users/garceau/.config/google-drive-mcp/gcp-oauth.keys.json`
- **python-docx:** already installed on Python 3.13
- **Surveys folder:** `1IZMybjosteoEy1xzx2Ws5S1CLg0lS4oM`
