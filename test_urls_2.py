import urllib.request
import ssl

urls = [
    "http://ntv.radyotvonline.com/ntvradyo",
    "http://178.211.51.53:8000/", # NTV Radyo alternative
    "https://listen.powerapp.com.tr/powerpop/mpeg/icecast.audio", # Power Pop
    "https://shoutcast.radyotvonline.net/kafaradyo",
    "https://listen.kafaradyo.com/kafa/128/icecast.audio",
    "http://46.20.7.125/listen.pls", # Pal FM alternative
    "http://shoutcast.radyotvonline.com/palfm",
    "https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_FM_SC"
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
