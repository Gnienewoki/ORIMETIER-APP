-- ============================================================
-- ORIMETIER — Bandeau d'annonce admin (site-wide)
-- PHASE 1 : création de la table annonce (singleton, comme admin_config),
-- RLS, et des 2 fonctions RPC admin (publier, retirer).
--
-- Ce script ne touche à aucun fichier du site et n'insère aucune donnée
-- (la ligne id=1 est créée par le premier appel à admin_publier_annonce,
-- pas par ce script).
--
-- Lecture publique ouverte (comme liens_formation/universites) ; écriture
-- bloquée pour anon/authenticated — uniquement via les 2 fonctions
-- SECURITY DEFINER ci-dessous, qui vérifient admin_config.admin_password.
--
-- À exécuter en une fois dans l'éditeur SQL de Supabase.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.annonce (
  id int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  type text NOT NULL CHECK (type IN ('texte','image')),
  texte text,
  image_url text,
  active boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.annonce IS 'Bandeau d''annonce admin, ligne unique (id=1) affichée site-wide quand active=true';

ALTER TABLE public.annonce ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lecture publique" ON public.annonce
  FOR SELECT TO anon, authenticated USING (true);

-- Crée ou remplace l'annonce et la publie (active=true). p_type doit être
-- 'texte' ou 'image' ; seul le champ correspondant (p_texte ou p_image_url)
-- a besoin d'être renseigné, mais les deux sont acceptés tels quels.
CREATE OR REPLACE FUNCTION public.admin_publier_annonce(
  p_admin_password text, p_type text, p_texte text, p_image_url text
)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then return false; end if;
  if p_type not in ('texte','image') then return false; end if;
  if p_type = 'texte' and length(trim(coalesce(p_texte,''))) = 0 then return false; end if;
  if p_type = 'image' and length(trim(coalesce(p_image_url,''))) = 0 then return false; end if;

  insert into annonce(id, type, texte, image_url, active, updated_at)
    values (1, p_type, p_texte, p_image_url, true, now())
    on conflict (id) do update
      set type = excluded.type, texte = excluded.texte, image_url = excluded.image_url,
          active = true, updated_at = now();
  return true;
end; $function$;

-- Retire l'annonce du site (active=false) sans effacer son contenu, pour
-- pouvoir la republier facilement ensuite sans tout ressaisir.
CREATE OR REPLACE FUNCTION public.admin_retirer_annonce(p_admin_password text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then return false; end if;
  update annonce set active = false, updated_at = now() where id = 1;
  return found;
end; $function$;
