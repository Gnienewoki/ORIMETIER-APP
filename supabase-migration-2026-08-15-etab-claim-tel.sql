-- À exécuter dans le SQL Editor de Supabase (production), après
-- supabase-migration-2026-08-15-admin-only-contact.sql.
-- ============================================================
-- Étend etablissement_claim_by_code() pour permettre à l'établissement de
-- renseigner/mettre à jour, au moment où il récupère son compte avec son
-- code, en plus de l'e-mail déjà géré :
--   - le nom du responsable (p_responsable)
--   - ses numéros de contact public (p_tel, p_tel2, p_tel3)
--   - son site web (p_site_web)
-- Toute la logique de vérification existante (code à usage unique, e-mail
-- déjà utilisé par un autre établissement) est conservée strictement à
-- l'identique. Les 5 nouveaux paramètres sont optionnels (DEFAULT NULL) :
-- les appels existants à 3 arguments (p_code, p_email, p_password) restent
-- valides sans changement. Un champ laissé vide ne remplace pas une valeur
-- déjà en base (utile si l'admin a déjà renseigné responsable/tel lors de la
-- pré-inscription en masse).
-- ============================================================

CREATE OR REPLACE FUNCTION public.etablissement_claim_by_code(
  p_code text, p_email text, p_password text,
  p_responsable text DEFAULT NULL, p_tel text DEFAULT NULL, p_tel2 text DEFAULT NULL, p_tel3 text DEFAULT NULL,
  p_site_web text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_etab record;
begin
  if coalesce(trim(p_code), '') = '' or coalesce(trim(p_email), '') = '' or coalesce(trim(p_password), '') = '' then
    return false;
  end if;
  select * into v_etab from etablissements where code_recuperation = p_code and reclame = false;
  if not found then return false; end if;
  if exists (select 1 from etablissements where email = p_email and id <> v_etab.id) then
    return false; -- e-mail déjà utilisé par un autre établissement
  end if;

  update etablissements
    set email = p_email, password = p_password, reclame = true, code_recuperation = null,
        responsable = coalesce(nullif(trim(p_responsable), ''), responsable),
        tel = coalesce(nullif(trim(p_tel), ''), tel),
        tel2 = coalesce(nullif(trim(p_tel2), ''), tel2),
        tel3 = coalesce(nullif(trim(p_tel3), ''), tel3),
        site_web = coalesce(nullif(trim(p_site_web), ''), site_web)
    where id = v_etab.id;
  return true;
end;
$function$;
