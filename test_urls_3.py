import urllib.request
import ssl

urls = [
    "http://144.91.73.57:8124/stream", # Kafa Radyo?
    "https://n101.radyotvonline.net/kafaradyo",
    "http://shoutcast.radyotvonline.net/ntvradyo",
    "http://144.91.73.57:8000/stream",
    "https://listen.radyofenomen.com/fenomen/128/icecast.audio",
    "http://sslv3.radyotvonline.net/palfm",
    "http://radyo.dogannet.tv/ntvradyo",
    "http://37.247.98.8/stream/166/" # NTV Radyo
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
