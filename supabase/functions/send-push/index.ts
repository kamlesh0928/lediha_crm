// Sends a Firebase push notification when the database creates an alert or a chat message.
// Called only by the database trigger (header x-push-secret). Deploy with "Verify JWT" OFF.
// Secrets needed: PUSH_WEBHOOK_SECRET (any long random text) and FCM_SERVICE_ACCOUNT (the whole
// Firebase service-account JSON file pasted as text).
import { createClient } from "npm:@supabase/supabase-js@2";

function secretKey(): string {
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    if (keys.default) return keys.default as string;
  } catch (_) { /* fall back below */ }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

const admin = createClient(Deno.env.get("SUPABASE_URL")!, secretKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});
const PUSH_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";

function serviceAccount(): any {
  try { return JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}"); } catch (_) { return {}; }
}

const b64url = (data: ArrayBuffer | Uint8Array) =>
  btoa(String.fromCharCode(...new Uint8Array(data))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

let cached: { token: string; exp: number } | null = null;

// Google OAuth access token from the service account (signed JWT, RS256).
async function accessToken(sa: any): Promise<string> {
  if (cached && cached.exp > Date.now() + 60_000) return cached.token;
  const now = Math.floor(Date.now() / 1000);
  const enc = new TextEncoder();
  const header = b64url(enc.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = b64url(enc.encode(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })));
  const pem = String(sa.private_key).replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, enc.encode(`${header}.${claims}`));
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(sig)}`,
    }),
  });
  if (!r.ok) throw new Error(`Google token ${r.status}: ${await r.text()}`);
  const j = await r.json();
  cached = { token: j.access_token, exp: Date.now() + (j.expires_in ?? 3600) * 1000 };
  return cached.token;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  if (!PUSH_SECRET || req.headers.get("x-push-secret") !== PUSH_SECRET) {
    return new Response("Forbidden", { status: 403 });
  }
  try {
    const sa = serviceAccount();
    if (!sa.project_id || !sa.private_key) return new Response("FCM_SERVICE_ACCOUNT is not set", { status: 500 });

    const { table, record } = await req.json();
    let users: string[] = [];
    let title = "";
    let body = "";
    const data: Record<string, string> = {};

    if (table === "notifications") {
      users = [record.user_id];
      title = record.title ?? "LEDiHA CRM";
      body = record.body ?? "";
      if (record.ref_table) data.ref_table = String(record.ref_table);
      if (record.ref_id) data.ref_id = String(record.ref_id);
    } else if (table === "messages") {
      const { data: sender } = await admin.from("profiles").select("full_name").eq("id", record.sender_id).single();
      title = sender?.full_name ?? "New message";
      body = String(record.body ?? "").slice(0, 120);
      if (record.recipient_id) {
        users = [record.recipient_id];
      } else {
        const { data: all } = await admin.from("profiles").select("id").eq("is_active", true).neq("id", record.sender_id);
        users = (all ?? []).map((p: { id: string }) => p.id);
        title = `Team chat - ${title}`;
      }
    } else {
      return new Response("ignored");
    }
    if (!users.length) return new Response("no recipients");

    const { data: rows } = await admin.from("device_tokens").select("token").in("user_id", users);
    if (!rows?.length) return new Response("no devices");

    const at = await accessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    let sent = 0;
    for (const { token } of rows) {
      const r = await fetch(url, {
        method: "POST",
        headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: { token, notification: { title, body }, data, android: { priority: "HIGH" } },
        }),
      });
      if (r.ok) {
        sent++;
      } else {
        const text = await r.text();
        // The app was uninstalled or the token expired: forget it.
        if (r.status === 404 || text.includes("UNREGISTERED")) {
          await admin.from("device_tokens").delete().eq("token", token);
        } else {
          console.error("FCM error", r.status, text);
        }
      }
    }
    return new Response(JSON.stringify({ sent }), { headers: { "Content-Type": "application/json" } });
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});
