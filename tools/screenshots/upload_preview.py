#!/usr/bin/env python3
"""Upload fastlane/app_previews/{ko,en}.mp4 to an App Store version's 6.9" iPhone preview set.

fastlane deliver cannot upload app previews, so this talks to the App Store Connect API directly.
Standard library only; the ES256 JWT is signed with the `openssl` CLI.

  python3 tools/screenshots/upload_preview.py --key ~/path/ios.key --version 3.1.0

--key is fastlane's API key JSON ({"key_id", "issuer_id", "key"}). Existing previews in the set
are replaced. The version must be editable (not yet submitted for review).
"""
import argparse, base64, hashlib, json, os, subprocess, sys, tempfile, time, urllib.error, urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE = "com.leesam.bomdongtycoon"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
# Our 6.9" captures (1320x2868) live in Apple's IPHONE_67 slot; the preview is 886x1920.
PREVIEW_TYPE = "IPHONE_67"
LOCALES = {"ko": "ko", "en-US": "en"}


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der):
    """openssl emits an ASN.1 DER ECDSA signature; JWS wants r || s, 32 bytes each."""
    i = 2 if der[1] < 0x80 else 3
    out = b""
    for _ in range(2):
        length = der[i + 1]
        out += der[i + 2:i + 2 + length].lstrip(b"\0").rjust(32, b"\0")
        i += 2 + length
    return out


def token(key):
    header = b64(json.dumps({"alg": "ES256", "kid": key["key_id"], "typ": "JWT"}).encode())
    now = int(time.time())
    claims = {"iss": key["issuer_id"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}
    signing_input = f"{header}.{b64(json.dumps(claims).encode())}"
    with tempfile.NamedTemporaryFile("w", suffix=".p8", delete=False) as f:
        f.write(key["key"])
    try:
        der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", f.name], input=signing_input.encode(),
                             capture_output=True, check=True).stdout
    finally:
        os.unlink(f.name)
    return f"{signing_input}.{b64(der_to_raw(der))}"


class Client:
    def __init__(self, key):
        self.key = key
        self._token, self._minted = None, 0

    def bearer(self):
        # Tokens live 1100 s; re-mint well before that instead of signing one per request.
        if self._token is None or time.time() - self._minted > 900:
            self._token, self._minted = token(self.key), time.time()
        return self._token

    def call(self, method, path, body=None):
        url = path if path.startswith("http") else API + path
        req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body else None)
        req.add_header("Authorization", "Bearer " + self.bearer())
        req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            sys.exit(f"{method} {path} -> {e.code}\n{e.read().decode()}")


def upload(client, set_id, path):
    data = open(path, "rb").read()
    preview = client.call("POST", "/appPreviews", {"data": {
        "type": "appPreviews",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(data), "mimeType": "video/mp4"},
        "relationships": {"appPreviewSet": {"data": {"type": "appPreviewSets", "id": set_id}}}}})["data"]
    for op in preview["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op["requestHeaders"]:
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req).read()
    client.call("PATCH", f"/appPreviews/{preview['id']}", {"data": {
        "type": "appPreviews", "id": preview["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return preview["id"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", required=True)
    ap.add_argument("--version", required=True)
    args = ap.parse_args()
    client = Client(json.load(open(os.path.expanduser(args.key))))

    app = client.call("GET", f"/apps?filter[bundleId]={BUNDLE}")["data"][0]
    versions = client.call("GET", f"/apps/{app['id']}/appStoreVersions"
                                  f"?filter[versionString]={args.version}&filter[platform]=IOS")["data"]
    if not versions:
        sys.exit(f"no App Store version {args.version}")
    version = versions[0]
    print(f"version {args.version}: {version['attributes']['appStoreState']}")

    pending = []
    for loc in client.call("GET", f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]:
        locale = loc["attributes"]["locale"]
        if locale not in LOCALES:
            continue
        sets = client.call("GET", f"/appStoreVersionLocalizations/{loc['id']}/appPreviewSets")["data"]
        preview_set = next((s for s in sets if s["attributes"]["previewType"] == PREVIEW_TYPE), None)
        if preview_set is None:
            preview_set = client.call("POST", "/appPreviewSets", {"data": {
                "type": "appPreviewSets", "attributes": {"previewType": PREVIEW_TYPE},
                "relationships": {"appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
        old = client.call("GET", f"/appPreviewSets/{preview_set['id']}/appPreviews")["data"]
        path = os.path.join(ROOT, "fastlane", "app_previews", LOCALES[locale] + ".mp4")
        # Upload first, delete after: a failed upload must not leave the live set empty.
        pending.append((locale, upload(client, preview_set["id"], path)))
        print(f"{locale}: uploaded {os.path.basename(path)}")
        for preview in old:
            client.call("DELETE", f"/appPreviews/{preview['id']}")

    if not pending:
        sys.exit(f"version {args.version} has none of the locales {sorted(LOCALES)}")

    # Apple transcodes the upload; wait until every preview is processed (or failed).
    for _ in range(60):
        states = {}
        for locale, pid in pending:
            attrs = client.call("GET", f"/appPreviews/{pid}")["data"]["attributes"]
            states[locale] = attrs["assetDeliveryState"]["state"]
            if states[locale] == "FAILED":
                sys.exit(f"{locale}: processing failed {attrs['assetDeliveryState'].get('errors')}")
        print("  " + ", ".join(f"{k}={v}" for k, v in states.items()))
        if all(s == "COMPLETE" for s in states.values()):
            print("all previews processed")
            return
        time.sleep(20)
    sys.exit("timed out waiting for processing")


if __name__ == "__main__":
    main()
