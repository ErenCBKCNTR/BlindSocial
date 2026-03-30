import urllib.request
import ssl

urls = [
    'https://hls.ntv.com.tr/ntv/live.m3u8',
    'https://hls.kanald.com.tr/kanald/live.m3u8',
    'https://hls.atv.com.tr/atv/live.m3u8',
    'https://live.dogannet.tv/S2/HLS_LIVE/cnnturk/cnnturk_720p/chunklist.m3u8',
    'https://ciner-live.ercdn.net/haberturk/haberturk_720p.m3u8',
    'https://dogus-live.ercdn.net/startv/startv.m3u8',
    'https://tv8-live.ercdn.net/tv8/tv8.m3u8'
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
