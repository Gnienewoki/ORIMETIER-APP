-- À exécuter dans le SQL Editor de Supabase (production), après
-- supabase-migration-2026-08-15-admin-only-contact.sql.
-- ============================================================
-- Aligne le tableau de bord établissement sur le nouveau découpage des champs
-- de contact (cf. supabase-migration-2026-08-15-admin-only-contact.sql) :
--   PUBLIC (masqué tant que premium=false) : email, site_web, tel, tel2, tel3
--   ADMIN UNIQUEMENT (jamais public) : responsable, contact_tel
--
-- 1) etablissement_update_info : définition réelle confirmée via
--    pg_get_functiondef('etablissement_update_info'::regproc) le 2026-08-16 —
--    7 params d'origine (p_etab_id, p_password, p_nom, p_type, p_responsable,
--    p_tel, p_email), pas de SET search_path, écrasement direct de tous les
--    champs (aucune protection NULLIF). On ajoute p_contact_tel en 8e
--    paramètre optionnel (DEFAULT NULL), protégé par COALESCE(NULLIF(...))
--    comme dans le claim : contrairement à nom/type/responsable/tel/email
--    (modifiés depuis le même formulaire, donc un champ vidé = valeur voulue),
--    contact_tel peut aussi être renseigné ailleurs (claim, register) et un
--    oubli ici ne doit pas effacer une valeur déjà en base.
CREATE OR REPLACE FUNCTION public.etablissement_update_info(p_etab_id text, p_password text, p_nom text, p_type text, p_responsable text, p_tel text, p_email text, p_contact_tel text DEFAULT NULL)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from etablissements where id = p_etab_id and password = p_password) then
    return false;
  end if;
  update etablissements
    set nom = p_nom, type = p_type, responsable = p_responsable, tel = p_tel, email = p_email,
        contact_tel = coalesce(nullif(trim(p_contact_tel), ''), contact_tel)
    where id = p_etab_id;
  return true;
end;
$function$;

-- 2) etablissement_update_contact_extras : définition réelle confirmée via
--    pg_get_functiondef('etablissement_update_contact_extras'::regproc) le
--    2026-08-16. Original : p_contact_email (colonne inutilisée) / p_contact_tel
--    (admin-only, jamais public) / p_site_web, gate premium=true, normalisation
--    '' -> NULL via nullif(trim(coalesce(...))). Ici : p_contact_email/p_contact_tel
--    renommés en p_tel2/p_tel3 (vraies colonnes publiques), gate premium retirée
--    (accessible à TOUT établissement — le masquage public reste automatique via
--    list_etablissements()), même normalisation '' -> NULL conservée. Vérifié en
--    prod : 0 établissement réel (hors TEST-) n'a de valeur dans contact_tel,
--    donc aucune perte de donnée publique en abandonnant cette colonne ici.
--    Signature toujours (text,text,text,text,text) : remplacement en place, pas
--    de nouvelle surcharge — mais les appels existants par p_contact_email/
--    p_contact_tel cesseront de fonctionner dès l'exécution (à appliquer une fois
--    le nouveau JS confirmé en ligne, jamais avant).
CREATE OR REPLACE FUNCTION public.etablissement_update_contact_extras(p_etab_id text, p_password text, p_tel2 text, p_tel3 text, p_site_web text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_etab record;
begin
  select * into v_etab from etablissements where id = p_etab_id and password = p_password;
  if not found then return false; end if;
  update etablissements
    set tel2 = nullif(trim(coalesce(p_tel2,'')),''),
        tel3 = nullif(trim(coalesce(p_tel3,'')),''),
        site_web = nullif(trim(coalesce(p_site_web,'')),'')
    where id = p_etab_id;
  return true;
end; $function$;
