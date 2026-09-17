import urllib.request, json, os
for k in ('HTTP_PROXY','HTTPS_PROXY','http_proxy','https_proxy','ALL_PROXY','all_proxy'):
    os.environ.pop(k, None)
try:
    r = urllib.request.urlopen('http://localhost:8080/api/characters', timeout=10)
    d = json.load(r)
    with open(r'D:\Documents\Desktop\Virtual\chars_out.txt','w',encoding='utf-8') as f:
        f.write('count=%d\n' % len(d))
        for c in d:
            f.write('%r | %s | %s\n' % (c.get('id'), c.get('name'), c.get('avatarUrl')))
except Exception as e:
    with open(r'D:\Documents\Desktop\Virtual\chars_out.txt','w',encoding='utf-8') as f:
        f.write('ERROR: %r\n' % e)
