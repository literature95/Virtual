import urllib.request, json, os
for k in ('HTTP_PROXY','HTTPS_PROXY','http_proxy','https_proxy','ALL_PROXY','all_proxy'):
    os.environ.pop(k, None)
from urllib.parse import quote
cid = quote('情满四合院')
try:
    r = urllib.request.urlopen('http://localhost:8080/api/characters/%s' % cid, timeout=10)
    d = json.load(r)
    with open(r'D:\detail_out.txt','w',encoding='utf-8') as f:
        f.write('keys=%s\n' % sorted(d.keys()))
        f.write('id=%r name=%r\n' % (d.get('id'), d.get('name')))
        f.write('avatarUrl=%r\n' % d.get('avatarUrl'))
        f.write('firstMessage_len=%d\n' % len(d.get('firstMessage') or ''))
        f.write('characterBook_present=%s\n' % ('characterBook' in d))
        cb = d.get('characterBook') or d.get('character_book')
        if isinstance(cb, dict):
            f.write('book_entries=%d\n' % len(cb.get('entries', [])))
        else:
            f.write('book_raw_type=%s\n' % type(cb).__name__)
        f.write('extensions_keys=%s\n' % list((d.get('extensions') or {}).keys()))
        f.write('rawCard_present=%s\n' % ('rawCard' in d or 'raw_card' in d))
except Exception as e:
    with open(r'D:\detail_out.txt','w',encoding='utf-8') as f:
        f.write('ERROR: %r\n' % e)
