import urllib.request
import ssl

urls = [
    "http://144.91.73.57:8124/stream",
    "http://46.20.13.51:1180/stream",
    "https://shoutcast.radyotvonline.net/palfm",
    "http://37.247.98.8/stream/166/",
    "http://radyo.dogannet.tv/ntv",
    "http://ntvradyo.medya.trt.com.tr/master.m3u8",
    "https://radyo.ntv.com.tr/ntvradyo.mp3"
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
