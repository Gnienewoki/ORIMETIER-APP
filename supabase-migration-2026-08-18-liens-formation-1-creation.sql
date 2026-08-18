-- ============================================================
-- ORIMETIER — Nouvelle page "Formations" (liens-formation.html)
-- PHASE 1 : création de la table liens_formation, RLS, et des 2 fonctions
-- RPC admin (créer/modifier, supprimer).
--
-- Ce script ne touche à aucun fichier du site et n'insère aucune donnée.
-- Lecture publique ouverte (comme universites/grandes_ecoles) ; écriture
-- bloquée pour anon/authenticated — uniquement via les 2 fonctions
-- SECURITY DEFINER ci-dessous, qui vérifient admin_config.admin_password
-- (même modèle que admin_post_message dans supabase-migration.sql).
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.liens_formation (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  titre text NOT NULL,
  description text NOT NULL,
  url text NOT NULL,
  audience text NOT NULL CHECK (audience IN ('inspecteur','eleve','etudiant','tous')),
  ordre int,
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.liens_formation IS 'Liens externes de formation, par audience cible (onglets de liens-formation.html)';

ALTER TABLE public.liens_formation ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lecture publique" ON public.liens_formation
  FOR SELECT TO anon, authenticated USING (true);

-- p_id NULL = création ; p_id renseigné = mise à jour. Retourne l'id de la ligne
-- créée/modifiée, ou NULL si le mot de passe admin est invalide ou les données incorrectes.
CREATE OR REPLACE FUNCTION public.admin_upsert_lien_formation(
  p_admin_password text, p_id bigint, p_titre text, p_description text,
  p_url text, p_audience text, p_ordre int DEFAULT NULL
)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id bigint;
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then return null; end if;
  if p_audience not in ('inspecteur','eleve','etudiant','tous') then return null; end if;
  if length(trim(coalesce(p_titre,''))) = 0 or length(trim(coalesce(p_url,''))) = 0 then return null; end if;

  if p_id is null then
    insert into liens_formation(titre, description, url, audience, ordre)
      values (p_titre, p_description, p_url, p_audience, p_ordre)
      returning id into v_id;
  else
    update liens_formation
      set titre = p_titre, description = p_description, url = p_url, audience = p_audience, ordre = p_ordre
      where id = p_id
      returning id into v_id;
  end if;
  return v_id;
end; $function$;

CREATE OR REPLACE FUNCTION public.admin_delete_lien_formation(p_admin_password text, p_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then return false; end if;
  delete from liens_formation where id = p_id;
  return found;
end; $function$;
