// Creates employee logins and resets passwords. Only an active admin may call it.
// Deploy:  supabase functions deploy manage-employee
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Who is calling?
    const caller = createClient(url, anon, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: { user } } = await caller.auth.getUser();
    if (!user) return json({ error: "Not signed in." }, 401);

    const admin = createClient(url, service);
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
