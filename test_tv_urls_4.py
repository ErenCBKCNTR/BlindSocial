import urllib.request
import ssl

urls = [
    'https://tv-trtspor.medya.trt.com.tr/master_720.m3u8',
    'https://tv-trtspor.medya.trt.com.tr/master.m3u8',
    'https://tv-trtspor1.medya.trt.com.tr/master.m3u8'
]

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

for u in urls:
    try:
        req = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0'})
        response = urllib.request.urlopen(req, context=ctx, timeout=5)
        print(f"OK: {u} (Code: {response.getcode()})")
    except Exception as e:
        print(f"FAIL: {u} - {e}")
