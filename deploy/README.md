# Deep-link deploy files — `moonlightstream.app` (HestiaCP)

These make shared links open the app when installed, else the Play Store.
App side (intent filters, `DeepLinkService`, `ShareService.shareLive`) is already
in the app — this is the web/domain half.

Web root on the server (HestiaCP): `/home/<user>/web/moonlightstream.app/public_html/`

---

## 1. `/.well-known/assetlinks.json` (Android App Links verification)

Copy `well-known/assetlinks.json` to:

```
public_html/.well-known/assetlinks.json
```

**Easiest:** Play Console → your app → *Test and release → Setup → App signing*
has a ready-made **"Digital Asset Links JSON"** snippet with the correct
fingerprint(s) already filled in — copy that whole block into
`assetlinks.json` (keep our extra debug fingerprint entry if you still want
verified links to work with local debug builds).

Otherwise, fill in the two placeholder fingerprints by hand:

- **`REPLACE_WITH_PLAY_APP_SIGNING_SHA256`** — same page → **App signing key
  certificate** → copy the `SHA-256 certificate fingerprint`.
- **`REPLACE_WITH_UPLOAD_KEY_SHA256`** — same page, **Upload key certificate**
  → `SHA-256 certificate fingerprint`.
  (Or locally: `keytool -list -v -keystore android/app/upload-keystore.jks -alias <alias>`)

The third fingerprint already in the file is the Android **debug** key on this
machine — handy for testing verified links with a debug build; harmless to leave
or remove for production.

Serve it as `application/json` with **no redirect** and reachable over plain
HTTPS (no auth, no HSTS preload issues). Verify:

```
curl -sI https://moonlightstream.app/.well-known/assetlinks.json   # 200, content-type json
```

Google verifies asynchronously after install. Force a re-check on a test device:
```
adb shell pm verify-app-links --re-verify com.app.moonlightstream
adb shell pm get-app-links com.app.moonlightstream
```

### HestiaCP note
`.well-known` may be blocked or handled by the ACME/Let's Encrypt template.
In the web domain's **Proxy/Backend template** or nginx conf, make sure
`location ^~ /.well-known/acme-challenge/` stays, and add:

```nginx
location = /.well-known/assetlinks.json {
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    try_files $uri =404;
}
```

Put custom nginx snippets in
`/home/<user>/conf/web/moonlightstream.app/nginx.conf_*` (or use the
"Edit Configuration" UI) so a HestiaCP rebuild doesn't wipe them, then
`systemctl reload nginx`.

---

## 2. Landing page for `/live/<uuid>` and `/post/<id>`

`live-landing.html` opens `moonlight://live/<uuid>` immediately and falls back
to the Play Store after ~1.2s. Wire it up so both paths serve this one file:

```nginx
location ~ ^/(live|post)/ {
    try_files /live-landing.html =404;
}
```

Copy `live-landing.html` to `public_html/live-landing.html` and put a
`logo.png` (192px+) at `public_html/logo.png`.

Update `APP_STORE_URL` in the file once the iOS app has a real App Store id
(safe to leave for now — Android is the only platform in this build).

---

## 3. iOS Universal Links — not needed yet

This repo has no `ios/` project. When iOS ships, add
`.well-known/apple-app-site-association` (JSON, no extension, `application/json`)
with the Team ID + bundle id, and the `applinks:moonlightstream.app`
associated-domain entitlement in Xcode.

---

## Quick test (Android, after deploy)

```
# custom scheme — always works, no verification
adb shell am start -a android.intent.action.VIEW -d "moonlight://live/<uuid>"

# verified https link
adb shell am start -a android.intent.action.VIEW -d "https://moonlightstream.app/live/<uuid>"
```
