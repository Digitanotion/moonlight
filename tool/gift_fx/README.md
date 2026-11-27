# Gift FX pipeline (macOS, no ffmpeg needed)

Turns an AI-made gift video on a solid blue / green / pink background into
the app's "side-by-side alpha" MP4 (left = colour, right = alpha).

    swiftc -O vk.swift -o vk && swiftc -O sbs.swift -o sbs
    # work dir needs: tool/ (these files + binaries), src/<code>.mp4
    zsh tool/keyall.sh <code>   # → k/<code>/f*.png  (width by price tier)
    zsh tool/encall.sh <code>   # → fx/<code>.mp4    (bitrate by price tier)

Then copy fx/<code>.mp4 to moonlight-api/public/gift-fx/<code>-v1.mp4 and
set gift_catalog.meta.fx = {url: "/gift-fx/<code>-v1.mp4", v: 1} (migration).

Keyer options (env): WARM=1 recolour blue glow gold (blue screens);
WARM=2 also turn purple semi-transparent glow gold (Bible);
FADE=0.22 fade the bottom 22% (Car's road). Lower lo/hi (e.g. 14 38)
keeps dark glass that reflects the backdrop solid (Wine).
