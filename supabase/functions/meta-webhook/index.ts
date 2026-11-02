// Receives Facebook / Instagram Lead Ads, WhatsApp and Messenger/Instagram DMs from Meta
// and turns each into a lead. Duplicates are ignored. Every event is logged in meta_events.
//
// Deploy (Meta does not send a Supabase login token, so JWT check must be off):
//   supabase functions deploy meta-webhook --no-verify-jwt
// Secrets:
//   supabase secrets set META_VERIFY_TOKEN=... META_APP_SECRET=... META_PAGE_ACCESS_TOKEN=...
import { createClient } from "npm:@supabase/supabase-js@2";

const VERIFY = Deno.env.get("META_VERIFY_TOKEN") ?? "";
const APP_SECRET = Deno.env.get("META_APP_SECRET") ?? "";
const PAGE_TOKEN = Deno.env.get("META_PAGE_ACCESS_TOKEN") ?? "";
const GRAPH = "https://graph.facebook.com/v21.0";

// Keys: prefer the new SUPABASE_SECRET_KEYS (JSON), fall back to the old SUPABASE_SERVICE_ROLE_KEY.
function secretKey(): string {
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    if (keys.default) return keys.default as string;
  } catch (_) { /* fall back below */ }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

const db = createClient(Deno.env.get("SUPABASE_URL")!, secretKey(), {
  auth: { persistSession: false, autoRefreshToken: false },
});

type LeadInput = Record<string, unknown>;

function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

async function validSignature(raw: string, header: string | null) {
  if (!APP_SECRET || !header?.startsWith("sha256=")) return false;
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(APP_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw));
  const hex = [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return safeEqual(hex, header.slice(7));
}

// ---- Facebook / Instagram Instant Form -------------------------------------------------
async function fromLeadgen(v: any): Promise<LeadInput> {
  const r = await fetch(`${GRAPH}/${v.leadgen_id}`, { headers: { Authorization: `Bearer ${PAGE_TOKEN}` } });
  if (!r.ok) throw new Error(`Graph API ${r.status}: ${await r.text()}`);
  const d = await r.json();
  const f: Record<string, string> = {};
  for (const x of d.field_data ?? []) f[String(x.name).toLowerCase()] = (x.values ?? [])[0] ?? "";
  const name = f["full_name"] || [f["first_name"], f["last_name"]].filter(Boolean).join(" ") || "Facebook lead";
  const platform = String(d.platform ?? "").toLowerCase();
  const known = ["full_name", "first_name", "last_name", "phone_number", "phone", "email", "city",
                 "tv_brand", "tv_model", "tv_issue", "issue"];
  const extra = Object.entries(f).filter(([k]) => !known.includes(k)).map(([k, val]) => `${k}: ${val}`).join("\n");
  return {
    external_id: `lead:${v.leadgen_id}`,
    customer_name: name,
    phone: f["phone_number"] || f["phone"] || null,
    email: f["email"] || null,
    area: f["city"] || null,
    tv_brand: f["tv_brand"] || null,
    tv_model: f["tv_model"] || null,
    issue: f["tv_issue"] || f["issue"] || null,
    source: platform === "ig" || platform === "instagram" ? "instagram" : "facebook",
    campaign: d.campaign_name ?? d.campaign_id ?? null,
    notes: extra || null,
  };
}

// ---- WhatsApp Cloud API: first message from a number creates a lead --------------------
function fromWhatsApp(m: any, contacts: any[]): LeadInput {
  const name = contacts?.find((c: any) => c.wa_id === m.from)?.profile?.name ?? "WhatsApp customer";
  return {
    external_id: `wa:${m.from}`,           // one lead per WhatsApp number
    customer_name: name,
    phone: `+${m.from}`,
    source: "whatsapp",
    notes: `First message: ${m.text?.body ?? `[${m.type}]`}`,
  };
}

// ---- Instagram / Messenger DM ----------------------------------------------------------
function fromDm(source: "instagram" | "messenger", msg: any): LeadInput | null {
  const sender = msg.sender?.id;
  if (!sender || msg.message?.is_echo) return null;
  return {
    external_id: `${source}:${sender}`,
    customer_name: source === "instagram" ? "Instagram user" : "Messenger user",
    phone: null,
    source,
    notes: `First message: ${msg.message?.text ?? "[attachment]"}\nSender id: ${sender}`,
  };
}

// Returns true when handled (or safely skipped), false when it failed and Meta should retry.
async function handle(eventId: string, source: string, payload: unknown, build: () => Promise<LeadInput | null>) {
  const ins = await db.from("meta_events").insert({ external_event_id: eventId, source, payload });
  if (ins.error) {
    if (ins.error.code !== "23505") { console.error(ins.error); return false; }
    const { data: ex } = await db.from("meta_events").select("status,attempts").eq("external_event_id", eventId).single();
    if (ex?.status !== "failed") return true;               // already handled
    await db.from("meta_events").update({ attempts: (ex.attempts ?? 0) + 1 }).eq("external_event_id", eventId);
  }
  try {
    const lead = await build();
    if (!lead) {
      await db.from("meta_events").update({ status: "processed", error: "ignored" }).eq("external_event_id", eventId);
      return true;
    }
    const { data, error } = await db.from("leads")
      .upsert({ status: "new", priority: "medium", ...lead }, { onConflict: "external_id", ignoreDuplicates: true })
      .select("id").maybeSingle();
    if (error) throw error;
    await db.from("meta_events")
      .update({ status: data ? "processed" : "duplicate", lead_id: data?.id ?? null, error: null })
      .eq("external_event_id", eventId);
    return true;
  } catch (e) {
    await db.from("meta_events")
      .update({ status: "failed", error: String((e as Error).message ?? e) })
      .eq("external_event_id", eventId);
    return false;
  }
}

async function processBody(body: any): Promise<boolean> {
  let ok = true;
  for (const entry of body.entry ?? []) {
    if (body.object === "whatsapp_business_account") {
      for (const ch of entry.changes ?? []) {
        const v = ch.value ?? {};
        for (const m of v.messages ?? []) {
          ok = (await handle(`evt:wa:${m.id}`, "whatsapp", m, async () => fromWhatsApp(m, v.contacts))) && ok;
        }
      }
    } else if (body.object === "instagram") {
      for (const msg of entry.messaging ?? []) {
        const mid = msg.message?.mid;
        if (mid) ok = (await handle(`evt:ig:${mid}`, "instagram", msg, async () => fromDm("instagram", msg))) && ok;
      }
    } else if (body.object === "page") {
      for (const ch of entry.changes ?? []) {
        if (ch.field === "leadgen") {
          ok = (await handle(`evt:lead:${ch.value.leadgen_id}`, "facebook", ch.value, () => fromLeadgen(ch.value))) && ok;
        }
      }
      for (const msg of entry.messaging ?? []) {
        const mid = msg.message?.mid;
        if (mid) ok = (await handle(`evt:fb:${mid}`, "messenger", msg, async () => fromDm("messenger", msg))) && ok;
      }
    }
  }
  return ok;
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  if (req.method === "GET") {   // Meta's one-time "verify this URL" check
    if (url.searchParams.get("hub.mode") === "subscribe" && url.searchParams.get("hub.verify_token") === VERIFY) {
      return new Response(url.searchParams.get("hub.challenge") ?? "", { status: 200 });
    }
    return new Response("Forbidden", { status: 403 });
  }
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const raw = await req.text();
  if (!(await validSignature(raw, req.headers.get("x-hub-signature-256")))) {
    return new Response("Bad signature", { status: 401 });
  }
  let body: any;
  try { body = JSON.parse(raw); } catch { return new Response("Bad JSON", { status: 400 }); }

  // 500 makes Meta retry the delivery later; handled events are skipped on retry.
  const ok = await processBody(body);
  return new Response(ok ? "EVENT_RECEIVED" : "RETRY", { status: ok ? 200 : 500 });
});
