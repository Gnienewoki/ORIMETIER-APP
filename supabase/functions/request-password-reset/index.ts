// ============================================================
// ORIMETIER — Edge Function request-password-reset (Phase 4b)
//
// Reçoit { role, email } depuis le formulaire "Mot de passe oublié".
// Génère le jeton de réinitialisation ICI (jamais dans le navigateur),
// n'enregistre en base que son empreinte sha256 (password_reset_create,
// réservée à service_role), puis envoie le lien par l'API REST d'EmailJS.
//
// Anti-énumération : toute requête bien formée reçoit { ok: true } tout de
// suite, et le travail (base + e-mail) se fait en arrière-plan
// (EdgeRuntime.waitUntil) : ni la réponse ni son délai ne révèlent si
// l'e-mail correspond à un compte.
//
// Journaux : jamais le jeton, le lien, l'empreinte, l'e-mail ni une clé.
//
// Secrets attendus (npx supabase secrets set / tableau de bord) :
//   APP_URL, EMAILJS_SERVICE_ID, EMAILJS_TEMPLATE_ID, EMAILJS_PUBLIC_KEY,
//   EMAILJS_PRIVATE_KEY
// Fournis automatiquement par Supabase : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// ============================================================

import { createClient } from "npm:@supabase/supabase-js@2";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;

const ROLES = ["eleve", "inspecteur", "etablissement"];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const EMAILJS_URL = "https://api.emailjs.com/api/v1.0/email/send";

function appUrl(): string {
  return (Deno.env.get("APP_URL") ?? "").replace(/\/+$/, "");
}

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": appUrl() || "null",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Vary": "Origin",
  };
}

function json(status: number, body: { ok: boolean }): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

// Empreinte calculée sur le TEXTE hexadécimal du jeton, comme
// encode(extensions.digest(p_token, 'sha256'), 'hex') dans reset_password_with_token.
async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return toHex(new Uint8Array(digest));
}

// Travail en arrière-plan : aucune erreur ne remonte au client.
async function traiterDemande(role: string, email: string): Promise<void> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const baseUrl = appUrl();
  const serviceId = Deno.env.get("EMAILJS_SERVICE_ID");
  const templateId = Deno.env.get("EMAILJS_TEMPLATE_ID");
  const publicKey = Deno.env.get("EMAILJS_PUBLIC_KEY");
  const privateKey = Deno.env.get("EMAILJS_PRIVATE_KEY");

  const manquants = Object.entries({
    SUPABASE_URL: supabaseUrl,
    SUPABASE_SERVICE_ROLE_KEY: serviceRoleKey,
    APP_URL: baseUrl,
    EMAILJS_SERVICE_ID: serviceId,
    EMAILJS_TEMPLATE_ID: templateId,
    EMAILJS_PUBLIC_KEY: publicKey,
    EMAILJS_PRIVATE_KEY: privateKey,
  }).filter(([, v]) => !v).map(([k]) => k);
  if (manquants.length) {
    console.error("[request-password-reset] secrets manquants :", manquants.join(", "));
    return;
  }

  const token = toHex(crypto.getRandomValues(new Uint8Array(32)));
  const tokenHash = await sha256Hex(token);

  const supabase = createClient(supabaseUrl!, serviceRoleKey!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: destinataire, error } = await supabase.rpc("password_reset_create", {
    p_role: role,
    p_email: email,
    p_token_hash: tokenHash,
  });
  if (error) {
    console.error("[request-password-reset] password_reset_create a échoué :", error.code, error.message);
    return;
  }
  // null : compte introuvable/banni ou limite atteinte. Rien à envoyer, rien à journaliser.
  if (typeof destinataire !== "string" || !destinataire) return;

  const resetLink = `${baseUrl}/#reset=${token}`;
  try {
    const res = await fetch(EMAILJS_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        service_id: serviceId,
        template_id: templateId,
        user_id: publicKey,
        accessToken: privateKey,
        template_params: { to_email: destinataire, reset_link: resetLink },
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) {
      const detail = (await res.text()).slice(0, 200);
      console.error("[request-password-reset] EmailJS a refusé l'envoi :", res.status, detail, "| rôle :", role, "| compte trouvé : oui");
    }
  } catch (e) {
    console.error("[request-password-reset] appel EmailJS impossible :", e instanceof Error ? e.message : String(e), "| rôle :", role, "| compte trouvé : oui");
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }
  if (req.method !== "POST") {
    return json(405, { ok: false });
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json(400, { ok: false });
  }
  const { role, email } = (body ?? {}) as { role?: unknown; email?: unknown };
  if (typeof role !== "string" || !ROLES.includes(role)) {
    return json(400, { ok: false });
  }
  if (typeof email !== "string") {
    return json(400, { ok: false });
  }
  const emailNormalise = email.trim().toLowerCase();
  if (emailNormalise.length > 254 || !EMAIL_RE.test(emailNormalise)) {
    return json(400, { ok: false });
  }

  const travail = traiterDemande(role, emailNormalise).catch((e) => {
    console.error("[request-password-reset] erreur inattendue :", e instanceof Error ? e.message : String(e));
  });
  if (typeof EdgeRuntime !== "undefined" && EdgeRuntime?.waitUntil) {
    EdgeRuntime.waitUntil(travail);
  } else {
    await travail; // exécution locale sans EdgeRuntime
  }

  return json(200, { ok: true });
});
