import urllib.request
import ssl

urls = [
    'https://video.haber7.com/video_player/livestream/atv.m3u8',
    'https://live.dogannet.tv/S2/HLS_LIVE/cnnturk/cnnturk.m3u8',
    'https://ciner-live.ercdn.net/haberturk/haberturk.m3u8',
    'https://live.dogannet.tv/S1/HLS_LIVE/kanaldnp/track_4000/chunklist.m3u8',
    'https://ntv-live-nmd1.sozcu.com.tr/out/v1/a29e4ba6f5ed42fe8bd320dae278f24b/index.m3u8',
    'https://tr-now.ercdn.net/now/now_720p.m3u8',
    'https://ciner-live.ercdn.net/showtv/showtv.m3u8',
    'https://dogus-live.ercdn.net/startv/startv_720p.m3u8',
    'https://tv-trt1.medya.trt.com.tr/master_720.m3u8',
    'https://tv8-live.ercdn.net/tv8/tv8_720p.m3u8'
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
