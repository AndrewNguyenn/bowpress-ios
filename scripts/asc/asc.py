#!/usr/bin/env python3
"""App Store Connect helper for BowPress.

Subcommands:
  list-bundles | list-certs | list-profiles | list-apps
  register-bundle-id  --bundle-id ID --name NAME [--capabilities CAP1,CAP2,...]
  create-cert         --type DISTRIBUTION --email EMAIL --common-name CN [--out DIR]
  create-profile      --bundle-id ID --name NAME --cert-ids ID1[,ID2] [--type IOS_APP_STORE] [--out DIR]
  create-app          --bundle-id ID --name NAME --sku SKU [--locale en-US]
  bootstrap           --email EMAIL   (runs the whole thing with BowPress defaults)

Credentials come from .env next to this script (see .env.example). Never commit .env.
"""
import argparse
import base64
import os
import subprocess
import sys
import time
import warnings
from pathlib import Path

warnings.filterwarnings("ignore", module="urllib3")

try:
    import jwt
    import requests
except ImportError:
    sys.stderr.write("missing deps — run: pip install -r requirements.txt\n")
    sys.exit(1)

API_BASE = "https://api.appstoreconnect.apple.com/v1"
SCRIPT_DIR = Path(__file__).parent
ENV_FILE = SCRIPT_DIR / ".env"


def load_env():
    if not ENV_FILE.exists():
        return
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def require_env(name: str) -> str:
    v = os.environ.get(name)
    if not v or v.startswith("PASTE_"):
        sys.exit(f"error: env var {name} is required (set in {ENV_FILE.name})")
    return v


def make_token() -> str:
    key_id = require_env("ASC_KEY_ID")
    issuer_id = require_env("ASC_ISSUER_ID")
    key_path = Path(require_env("ASC_KEY_PATH")).expanduser()
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + 20 * 60, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, key_path.read_text(), algorithm="ES256",
                      headers={"kid": key_id, "typ": "JWT"})


def api(method, path, *, token=None, **kwargs):
    token = token or make_token()
    headers = kwargs.pop("headers", {})
    headers["Authorization"] = f"Bearer {token}"
    headers.setdefault("Content-Type", "application/json")
    url = path if path.startswith("http") else f"{API_BASE}{path}"
    r = requests.request(method, url, headers=headers, timeout=30, **kwargs)
    if not r.ok:
        sys.stderr.write(f"{method} {url} -> {r.status_code}\n{r.text}\n")
        r.raise_for_status()
    return r.json() if r.text else None


# ---- list ----

def cmd_list_bundles(_):
    for b in api("GET", "/bundleIds?limit=200")["data"]:
        a = b["attributes"]
        print(f"{b['id']:20s}  {a['identifier']:45s}  {a.get('name','')}")


def cmd_list_certs(_):
    for c in api("GET", "/certificates?limit=200")["data"]:
        a = c["attributes"]
        print(f"{c['id']:20s}  {a['certificateType']:22s}  {a.get('name','')}  exp={a.get('expirationDate','')}")


def cmd_list_profiles(_):
    for p in api("GET", "/profiles?limit=200")["data"]:
        a = p["attributes"]
        print(f"{p['id']:20s}  {a['profileType']:22s}  {a.get('name',''):40s}  state={a.get('profileState','')}")


def cmd_list_apps(_):
    for app in api("GET", "/apps?limit=200")["data"]:
        a = app["attributes"]
        print(f"{app['id']:20s}  {a.get('bundleId',''):40s}  {a.get('name','')}")


# ---- bundle id ----

def find_bundle(identifier: str):
    data = api("GET", f"/bundleIds?filter[identifier]={identifier}&limit=1")
    items = data.get("data", [])
    return items[0] if items else None


def cmd_register_bundle_id(args):
    existing = find_bundle(args.bundle_id)
    if existing:
        print(f"bundle id exists: {existing['id']} ({args.bundle_id})")
        bundle = existing
    else:
        body = {"data": {"type": "bundleIds", "attributes": {
            "identifier": args.bundle_id, "name": args.name, "platform": "IOS",
        }}}
        bundle = api("POST", "/bundleIds", json=body)["data"]
        print(f"created bundle id {bundle['id']} ({args.bundle_id})")

    caps = [c.strip() for c in (args.capabilities or "").split(",") if c.strip()]
    for cap in caps:
        cap_body = {"data": {
            "type": "bundleIdCapabilities",
            "attributes": {"capabilityType": cap},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}}},
        }}
        try:
            api("POST", "/bundleIdCapabilities", json=cap_body)
            print(f"  enabled capability: {cap}")
        except requests.HTTPError as e:
            txt = (e.response.text or "").lower()
            if "duplicate" in txt or "already" in txt or e.response.status_code == 409:
                print(f"  capability already enabled: {cap}")
            else:
                raise


# ---- certificate ----

def cmd_create_cert(args):
    out = Path(args.out).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)
    key_path = out / f"{args.type.lower()}_key.pem"
    csr_path = out / f"{args.type.lower()}.csr"
    cer_path = out / f"{args.type.lower()}.cer"
    pem_cert_path = out / f"{args.type.lower()}.pem"
    p12_path = out / f"{args.type.lower()}.p12"

    if not key_path.exists():
        subprocess.run(["openssl", "genrsa", "-out", str(key_path), "2048"], check=True)
    subprocess.run([
        "openssl", "req", "-new", "-key", str(key_path), "-out", str(csr_path),
        "-subj", f"/emailAddress={args.email}/CN={args.common_name}/C=US",
    ], check=True)

    csr_lines = csr_path.read_text().strip().splitlines()
    csr_b64 = "".join(l for l in csr_lines if not l.startswith("-----"))

    body = {"data": {"type": "certificates", "attributes": {
        "certificateType": args.type, "csrContent": csr_b64,
    }}}
    cert = api("POST", "/certificates", json=body)["data"]
    cer_path.write_bytes(base64.b64decode(cert["attributes"]["certificateContent"]))

    subprocess.run(["openssl", "x509", "-inform", "DER", "-in", str(cer_path),
                    "-out", str(pem_cert_path)], check=True)
    p12_pass = args.p12_password
    subprocess.run(["openssl", "pkcs12", "-export",
                    "-inkey", str(key_path), "-in", str(pem_cert_path),
                    "-out", str(p12_path), "-passout", f"pass:{p12_pass}"], check=True)

    print(f"created certificate {cert['id']} ({args.type})")
    print(f"  .cer:         {cer_path}")
    print(f"  private key:  {key_path}")
    print(f"  .p12:         {p12_path}  (password: {p12_pass})")
    print(f"  → double-click the .p12 to install into Keychain; Xcode will pick it up.")
    return cert["id"]


# ---- profile ----

def cmd_create_profile(args):
    bundle = find_bundle(args.bundle_id)
    if not bundle:
        sys.exit(f"bundle id not found: {args.bundle_id} — run register-bundle-id first")

    cert_ids = [c.strip() for c in args.cert_ids.split(",") if c.strip()]
    body = {"data": {
        "type": "profiles",
        "attributes": {"name": args.name, "profileType": args.type},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
            "certificates": {"data": [{"type": "certificates", "id": c} for c in cert_ids]},
        },
    }}
    prof = api("POST", "/profiles", json=body)["data"]
    out = Path(args.out).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)
    path = out / f"{args.name.replace(' ', '_')}.mobileprovision"
    path.write_bytes(base64.b64decode(prof["attributes"]["profileContent"]))
    print(f"created profile {prof['id']}  saved: {path}")
    return prof["id"]


# ---- app ----

def cmd_create_app(args):
    body = {"data": {"type": "apps", "attributes": {
        "bundleId": args.bundle_id, "name": args.name,
        "primaryLocale": args.locale, "sku": args.sku,
    }}}
    try:
        app = api("POST", "/apps", json=body)["data"]
        print(f"created App Store Connect record {app['id']} ({args.name})")
    except requests.HTTPError as e:
        if e.response.status_code == 403:
            sys.stderr.write(
                "ASC API does not allow creating apps for this team — "
                "create the record manually at https://appstoreconnect.apple.com/apps\n"
            )
            return
        raise


# ---- bootstrap ----

def cmd_bootstrap(args):
    ns = argparse.Namespace

    print("== 1/4 register bundle id ==")
    cmd_register_bundle_id(ns(
        bundle_id=args.bundle_id, name=args.name,
        capabilities="PUSH_NOTIFICATIONS,APPLE_ID_AUTH,IN_APP_PURCHASE",
    ))

    print("\n== 2/4 create distribution certificate ==")
    cert_id = cmd_create_cert(ns(
        type="DISTRIBUTION", out=args.out,
        email=args.email, common_name=f"{args.name} Distribution",
        p12_password=args.p12_password,
    ))

    print("\n== 3/4 create App Store provisioning profile ==")
    cmd_create_profile(ns(
        bundle_id=args.bundle_id, type="IOS_APP_STORE",
        name=f"{args.name} AppStore", cert_ids=cert_id, out=args.out,
    ))

    print("\n== 4/4 App Store Connect app record ==")
    print("  SKIP: Apple's ASC API does not allow POST /apps for most teams.")
    print("  Create the app record manually at https://appstoreconnect.apple.com/apps:")
    print(f"    My Apps → + → New App")
    print(f"    Platform: iOS   Name: {args.name}   Language: English (U.S.)")
    print(f"    Bundle ID: {args.bundle_id} (pick from dropdown)   SKU: {args.sku}")

    print("\ndone. next steps:")
    print(f"  1. double-click {args.out}/distribution.p12 (password: bowpress) to import into Keychain")
    print(f"  2. create the app record in App Store Connect (see above)")
    print(f"  3. add DEVELOPMENT_TEAM = DFT522PW2V to project.yml and regenerate the xcodeproj")
    print(f"  4. in Xcode, under Signing & Capabilities → Release, pick profile '{args.name} AppStore'")


def main():
    load_env()
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list-bundles").set_defaults(func=cmd_list_bundles)
    sub.add_parser("list-certs").set_defaults(func=cmd_list_certs)
    sub.add_parser("list-profiles").set_defaults(func=cmd_list_profiles)
    sub.add_parser("list-apps").set_defaults(func=cmd_list_apps)

    rb = sub.add_parser("register-bundle-id")
    rb.add_argument("--bundle-id", required=True)
    rb.add_argument("--name", required=True)
    rb.add_argument("--capabilities", default="")
    rb.set_defaults(func=cmd_register_bundle_id)

    cc = sub.add_parser("create-cert")
    cc.add_argument("--type", default="DISTRIBUTION",
                    choices=["DISTRIBUTION", "DEVELOPMENT", "IOS_DISTRIBUTION", "IOS_DEVELOPMENT"])
    cc.add_argument("--out", default="./certs")
    cc.add_argument("--email", required=True)
    cc.add_argument("--common-name", required=True)
    cc.add_argument("--p12-password", default="bowpress")
    cc.set_defaults(func=cmd_create_cert)

    cp = sub.add_parser("create-profile")
    cp.add_argument("--bundle-id", required=True)
    cp.add_argument("--type", default="IOS_APP_STORE")
    cp.add_argument("--name", required=True)
    cp.add_argument("--cert-ids", required=True, help="comma-separated certificate IDs")
    cp.add_argument("--out", default="./profiles")
    cp.set_defaults(func=cmd_create_profile)

    ca = sub.add_parser("create-app")
    ca.add_argument("--bundle-id", required=True)
    ca.add_argument("--name", required=True)
    ca.add_argument("--sku", required=True)
    ca.add_argument("--locale", default="en-US")
    ca.set_defaults(func=cmd_create_app)

    bs = sub.add_parser("bootstrap")
    bs.add_argument("--bundle-id", default="com.andrewnguyen.bowpress")
    bs.add_argument("--name", default="BowPress")
    bs.add_argument("--sku", default="BOWPRESS")
    bs.add_argument("--email", required=True)
    bs.add_argument("--out", default="./certs")
    bs.add_argument("--p12-password", default="bowpress")
    bs.set_defaults(func=cmd_bootstrap)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
