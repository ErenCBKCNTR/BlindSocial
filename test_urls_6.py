import urllib.request
import ssl

urls = [
    "http://37.247.98.8/stream/166/", # Joy FM OK
    "https://moondigitaledge.radyotvonline.net/kafaradyo/playlist.m3u8", # Kafa Radyo OK
    "http://46.20.7.125/listen.pls", # NTV? Pal FM?
    "https://playerservices.streamtheworld.com/api/livestream-redirect/JOY_FM_SC", # Joy FM OK
    "https://n101.radyotvonline.com/ntvradyo/playlist.m3u8",
    "http://sslv3.radyotvonline.com/ntvradyo/playlist.m3u8",
    "https://moondigitaledge.radyotvonline.net/ntvradyo/playlist.m3u8", # Trying NTV Radyo
    "https://moondigitaledge.radyotvonline.net/palfm/playlist.m3u8" # Trying Pal FM
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
