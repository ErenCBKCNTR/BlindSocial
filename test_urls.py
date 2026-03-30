import urllib.request
import ssl

urls = [
    "https://n101.radyotvonline.net/ntvradyo",
    "https://ntv.radyotvonline.net/ntvradyo",
    "http://ntv.radyotvonline.net/ntvradyo",
    "https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_FM_SC",
    "http://shoutcast.radyotvonline.com/pal_fm",
    "http://46.20.7.125/listen.pls",
    "https://kafaradyo.radyotvonline.net/kafaradyo",
    "https://listen.kafaradyo.com/kafaradyo/128/icecast.audio",
    "https://playerservices.streamtheworld.com/api/livestream-redirect/PAL_FM_SC"
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
