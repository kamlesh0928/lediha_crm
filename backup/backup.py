"""Nightly backup: downloads every table through the Supabase REST API and writes CSV files.
Needs env vars SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (keep them in GitHub Secrets)."""
import csv, json, os, sys, urllib.request, urllib.parse, datetime

URL = os.environ["SUPABASE_URL"].rstrip("/")
KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
TABLES = ["profiles", "leads", "followups", "tasks", "attendance", "location_pings",
          "messages", "finance_entries", "notifications", "meta_events", "audit_logs"]
OUT = os.path.join("backup_out", datetime.date.today().isoformat())
os.makedirs(OUT, exist_ok=True)
PAGE = 1000


def fetch(table, offset):
    q = urllib.parse.urlencode({"select": "*", "order": "id.asc",
                                "limit": PAGE, "offset": offset})
    req = urllib.request.Request(f"{URL}/rest/v1/{table}?{q}",
                                 headers={"apikey": KEY, "Authorization": f"Bearer {KEY}"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


failed = False
for t in TABLES:
    try:
        rows, off = [], 0
        while True:
            chunk = fetch(t, off)
            rows += chunk
            if len(chunk) < PAGE:
                break
            off += PAGE
        cols = sorted({k for r in rows for k in r})
        with open(os.path.join(OUT, f"{t}.csv"), "w", newline="", encoding="utf-8-sig") as f:
            w = csv.writer(f)
            w.writerow(cols)
            for r in rows:
                w.writerow([json.dumps(r[c], ensure_ascii=False) if isinstance(r.get(c), (dict, list)) else r.get(c) for c in cols])
        print(f"{t}: {len(rows)} rows")
    except Exception as e:  # keep going so one bad table does not stop the rest
        failed = True
        print(f"{t}: FAILED {e}", file=sys.stderr)
sys.exit(1 if failed else 0)
