-- À exécuter dans le SQL Editor de Supabase (production), EN SECOND
-- (2 sur 3), après supabase-migration-2026-08-16-demandes-inscription-1-table.sql.
-- ============================================================
-- 1) etablissement_verifier_doublon : vérifie maintenant aussi les demandes
--    en attente (statut_demande = 'en_attente'), pas seulement les
--    établissements déjà créés — sinon deux personnes pourraient soumettre
--    la même demande pendant que l'admin la traite sans que l'avertissement
--    temps réel ne le détecte. Signature/comportement inchangés côté appelant.
--
-- 2) etablissement_register (version en prod, 20 paramètres) :
--    - Blocage anti-doublon (RAISE EXCEPTION 'DOUBLON: ...') strictement
--      identique au message existant, étendu aux deux tables (mêmes deux
--      lignes de raison ci-dessus).
--    - L'INSERT INTO etablissements est remplacé par un INSERT INTO
--      demandes_inscription_etablissements avec les mêmes valeurs (p_id
--      n'est plus utilisé : id de demande auto-généré par la table).
--    - Toute la logique restante (validations nom/ville/email/password,
--      vérification email déjà utilisé, valeur de retour boolean) est
--      conservée à l'identique.
--    - Signature inchangée -> CREATE OR REPLACE suffit (pas de DROP requis).
-- ============================================================

CREATE OR REPLACE FUNCTION public.etablissement_verifier_doublon(p_nom text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT
    EXISTS(
      SELECT 1 FROM etablissements
      WHERE lower(trim(nom)) = lower(trim(p_nom))
    )
    OR EXISTS(
      SELECT 1 FROM demandes_inscription_etablissements
      WHERE statut_demande = 'en_attente' AND lower(trim(nom)) = lower(trim(p_nom))
    );
$function$;

CREATE OR REPLACE FUNCTION public.etablissement_register(
  p_id text, p_nom text, p_region text, p_ville text, p_quartier text, p_type text,
  p_responsable text, p_tel text, p_email text, p_password text, p_date_inscription text,
  p_filieres_proposees jsonb, p_photos jsonb DEFAULT '[]'::jsonb,
  p_categorie text DEFAULT NULL::text, p_sous_categorie text DEFAULT NULL::text, p_secteur text DEFAULT NULL::text,
  p_tel2 text DEFAULT NULL::text, p_tel3 text DEFAULT NULL::text, p_site_web text DEFAULT NULL::text,
  p_contact_tel text DEFAULT NULL::text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if p_nom is null or length(trim(p_nom)) = 0 then return false; end if;
  if p_ville is null or length(trim(p_ville)) = 0 then return false; end if;
  if p_email is null or length(trim(p_email)) = 0 then return false; end if;
  if p_password is null or length(trim(p_password)) = 0 then return false; end if;

  if exists (select 1 from etablissements where lower(trim(nom)) = lower(trim(p_nom)))
     or exists (
       select 1 from demandes_inscription_etablissements
       where statut_demande = 'en_attente' and lower(trim(nom)) = lower(trim(p_nom))
     )
  then
    raise exception 'DOUBLON: Établissement déjà préinscrit, contacter le support pour récupérer vos codes de connexion. Tél : 07 87 63 34 81 - Email : gnienewoki@gmail.com';
  end if;

  if exists (select 1 from etablissements where email = p_email) then return false; end if;

  insert into demandes_inscription_etablissements(
    nom, region, ville, quartier, type, responsable, tel, tel2, tel3, email, password,
    date_inscription, filieres_proposees, photos, categorie, sous_categorie, secteur, site_web, contact_tel
  ) values (
    p_nom, p_region, p_ville, p_quartier, p_type, p_responsable, p_tel, p_tel2, p_tel3, p_email, p_password,
    p_date_inscription, coalesce(p_filieres_proposees, '[]'::jsonb), coalesce(p_photos, '[]'::jsonb),
    p_categorie, p_sous_categorie, p_secteur, p_site_web, p_contact_tel
  );
  return true;
end;
$function$;
