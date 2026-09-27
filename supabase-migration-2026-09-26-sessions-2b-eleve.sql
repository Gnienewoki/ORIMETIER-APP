-- Phase 2b élève : suppression des anciennes RPC par mot de passe,
-- remplacées par eleve_session_open / eleve_save_riasec(p_token, …) /
-- eleve_update_email(p_token, …) (migration 2a, en production depuis le 2026-09-26).
-- Signatures reprises de supabase/reference/live-2026-09-26.sql (l. 555, 566, 578).
-- ATTENTION : ne pas toucher aux surcharges par jeton eleve_save_riasec(text, jsonb)
-- et eleve_update_email(text, text).

DROP FUNCTION IF EXISTS public.eleve_login(text, text);
DROP FUNCTION IF EXISTS public.eleve_save_riasec(text, text, jsonb);
DROP FUNCTION IF EXISTS public.eleve_update_email(text, text, text);
