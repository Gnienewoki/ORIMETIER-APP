// ============================================================
// ---- Identifiants publics Supabase (seul endroit où ils sont écrits) ----
// ============================================================
// Chargé avant supabase-client.js sur toutes les pages applicatives, et seul par la page
// d'accueil (index.html), qui n'embarque pas supabase-js et appelle log_visite en fetch direct.
// ⚠️ Remplace ces deux valeurs par celles de TON projet Supabase
// (Supabase > Project Settings > API > Project URL / anon public key)
const SUPABASE_URL = 'https://ltfxaxzkuyejcluoaimq.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_h7s1eQ5VX8iBU2KYTpnZ3w_xRB9Mbl7';
