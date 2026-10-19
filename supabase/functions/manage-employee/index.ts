// Creates employee logins and resets passwords. Only an active admin may call it.
// Deploy: Supabase dashboard > Edge Functions > Deploy a new function (Via Editor), then turn Verify JWT OFF.
// CLI alternative: supabase functions deploy manage-employee --no-verify-jwt
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

// Keys: Supabase injects the new SUPABASE_SECRET_KEYS (JSON) and still injects the old
// SUPABASE_SERVICE_ROLE_KEY. We prefer the new one.
function secretKey(): string {
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    if (keys.default) return keys.default as string;
  } catch (_) { /* fall back below */ }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, secretKey(), {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Who is calling? Validate the signed-in user's token ourselves
    // (turn "Verify JWT" OFF for this function: the platform check does not work with the new keys).
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    if (!token) return json({ error: "Not signed in." }, 401);
    const { data: { user } } = await admin.auth.getUser(token);
    if (!user) return json({ error: "Not signed in." }, 401);

    const { data: me } = await admin.from("profiles").select("role,is_active").eq("id", user.id).single();
    if (!me || me.role !== "admin" || !me.is_active) return json({ error: "Admins only." }, 403);

    const body = await req.json();

    if (body.action === "create") {
      const { email, password, full_name, phone, role } = body;
      if (!email || !full_name || !password || String(password).length < 8) {
        return json({ error: "Name, email and a password of 8+ characters are required." }, 400);
      }
      const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
      if (error) return json({ error: error.message }, 400);
      const { error: e2 } = await admin.from("profiles").insert({
        id: data.user.id,
        full_name,
        phone: phone || null,
        email,
        role: role === "admin" ? "admin" : "employee",
      });
      if (e2) {
        await admin.auth.admin.deleteUser(data.user.id); // roll back, no half-created account
        return json({ error: e2.message }, 400);
      }
      return json({ ok: true, id: data.user.id });
    }

    if (body.action === "reset_password") {
      const { user_id, password } = body;
      if (!user_id || !password || String(password).length < 8) {
        return json({ error: "A password of 8+ characters is required." }, 400);
      }
      const { error } = await admin.auth.admin.updateUserById(user_id, { password });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: "Unknown action." }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
