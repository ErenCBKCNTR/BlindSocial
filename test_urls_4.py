import urllib.request
import ssl

urls = [
    "https://listen.radyofenomen.com/fenomenturk/128/icecast.audio",
    "http://shoutcast.radyotvonline.com:80/kafaradyo",
    "https://n101.radyotvonline.com/kafaradyo",
    "https://moondigitaledge.radyotvonline.net/kafaradyo/playlist.m3u8",
    "https://kafaradyo.turkmedya.com.tr/kafaradyo",
    "http://46.20.7.126:8080/listen.pls", # Pal FM
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
