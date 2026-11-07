#!/usr/bin/env python3
"""Da docs/pubblicazione/testi-legali.md genera LegalContent.swift e le pagine pubbliche."""
import html, json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'docs/pubblicazione/testi-legali.md'
SWIFT = ROOT / 'ios/StyleVaultNative/Profile/LegalContent.swift'
PAGES = ROOT / 'docs/pubblicazione/pagine'
IDS = ['privacy', 'support', 'deleteAccount']
FILES = {'privacy': 'privacy.html', 'support': 'supporto.html', 'deleteAccount': 'elimina-account.html'}


def parse(text):
    languages = {}
    for block in re.split(r'^## ', text, flags=re.M)[1:]:
        name, _, body = block.partition('\n')
        code = 'it' if name.strip() == 'Italiano' else 'en'
        head, *docs = re.split(r'^### ', body, flags=re.M)
        documents = []
        for doc in docs:
            title, _, rest = doc.partition('\n')
            intro, *parts = re.split(r'^#### ', rest, flags=re.M)
            sections = [{'heading': '', 'paragraphs': paragraphs(intro)}] if intro.strip() else []
            for part in parts:
                heading, _, content = part.partition('\n')
                sections.append({'heading': heading.strip(), 'paragraphs': paragraphs(content)})
            documents.append({'title': title.strip(), 'sections': sections})
        languages[code] = {'updated': head.strip(), 'documents': documents}
    return languages


def paragraphs(text):
    return [p.strip() for p in text.split('\n\n') if p.strip()]


def swift(languages):
    out = ['// Generato da scripts/testi-legali.py: si modifica docs/pubblicazione/testi-legali.md.', '',
           'enum LegalContent {']
    for code in ('it', 'en'):
        language = languages[code]
        out.append(f'    static let {code}Updated = {json.dumps(language["updated"], ensure_ascii=False)}')
        out.append(f'    static let {code}: [LegalDocument.Kind: LegalDocument] = [')
        for kind, document in zip(IDS, language['documents']):
            out.append(f'        .{kind}: LegalDocument(title: {json.dumps(document["title"], ensure_ascii=False)}, sections: [')
            for section in document['sections']:
                texts = ', '.join(json.dumps(p, ensure_ascii=False) for p in section['paragraphs'])
                out.append(f'            .init(heading: {json.dumps(section["heading"], ensure_ascii=False)}, paragraphs: [{texts}]),')
            out.append('        ]),')
        out.append('    ]')
    out.append('}')
    return '\n'.join(out) + '\n'


def page(languages, index):
    body = []
    for code in ('it', 'en'):
        language, document = languages[code], languages[code]['documents'][index]
        body.append(f'<article lang="{code}"><h1>{html.escape(document["title"])}</h1><p class="d">{html.escape(language["updated"])}</p>')
        for section in document['sections']:
            if section['heading']:
                body.append(f'<h2>{html.escape(section["heading"])}</h2>')
            body.extend(f'<p>{html.escape(p)}</p>' for p in section['paragraphs'])
        body.append('</article>')
    title = html.escape(languages['it']['documents'][index]['title'])
    return ('<!doctype html><html lang="it"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1">'
            f'<title>StyleVault — {title}</title><style>'
            'body{margin:0;background:#FAF7F2;color:#1A1A1A;font:17px/1.55 -apple-system,system-ui,sans-serif}'
            'article{max-width:680px;margin:0 auto;padding:32px 16px}h1{font:600 30px/1.2 Georgia,serif}'
            'h2{font-size:18px;margin-top:28px}.d{color:#6B6560;font-size:14px}'
            '@media(prefers-color-scheme:dark){body{background:#141210;color:#F2EDE6}.d{color:#A39B91}}'
            '</style></head><body>' + ''.join(body) + '</body></html>\n')


languages = parse(SOURCE.read_text(encoding='utf-8'))
SWIFT.write_text(swift(languages), encoding='utf-8')
PAGES.mkdir(parents=True, exist_ok=True)
for index, kind in enumerate(IDS):
    (PAGES / FILES[kind]).write_text(page(languages, index), encoding='utf-8')
print('ok', [len(languages[c]['documents']) for c in ('it', 'en')])
