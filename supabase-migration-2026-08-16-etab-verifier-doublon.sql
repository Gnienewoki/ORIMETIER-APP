-- À exécuter dans le SQL Editor de Supabase (production), EN PREMIER,
-- avant supabase-migration-2026-08-16-etab-register-bloque-doublon.sql.
-- ============================================================
-- Nouvelle RPC de lecture seule, utilisée par le formulaire d'inscription
-- directe d'établissement pour un avertissement en temps réel (non
-- bloquant) pendant la saisie du nom. Comparaison insensible à la casse
-- et aux espaces : lower(trim(nom)).
-- ============================================================

CREATE OR REPLACE FUNCTION public.etablissement_verifier_doublon(p_nom text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS(
    SELECT 1 FROM etablissements
    WHERE lower(trim(nom)) = lower(trim(p_nom))
  );
$function$;
