-- ============================================================
-- Migration MBTI — Espace inspecteur uniquement (élèves n'y ont pas accès)
-- Réplique le pattern d'auth et de structure de LYCAM
-- Date : 2026-08-21
-- ============================================================

-- ---------- Tables ----------

CREATE TABLE IF NOT EXISTS mbti_sessions (
  id text PRIMARY KEY,
  inspecteur_id text NOT NULL,
  nom text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mbti_resultats (
  id text PRIMARY KEY,
  session_id text NOT NULL REFERENCES mbti_sessions(id) ON DELETE CASCADE,
  inspecteur_id text NOT NULL,
  nom text,
  prenom text,
  naissance text,
  classe text,
  -- scores bruts des 8 listes (0 à 10 chacune) : {"E":7,"I":3,"S":4,"N":6,"T":8,"F":2,"J":3,"P":7}
  scores jsonb NOT NULL,
  -- type final validé, ex. "ENTP" — toujours résolu (égalités tranchées côté client avant envoi)
  type_letters text NOT NULL,
  -- hiérarchie des fonctions, ex. {"dominante":"Ne","auxiliaire":"Ti","tertiaire":"Fe","inferieure":"Si"}
  hierarchie jsonb NOT NULL,
  -- axes où il y a eu égalité de score, tranchés manuellement par l'inspecteur — trace d'audit
  -- ex. ["E/I"] ou [] si aucune égalité
  egalites jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mbti_resultats_session ON mbti_resultats(session_id);
CREATE INDEX IF NOT EXISTS idx_mbti_sessions_inspecteur ON mbti_sessions(inspecteur_id);

-- ---------- RPCs (miroir exact du pattern inspecteur_lycam_*) ----------

CREATE OR REPLACE FUNCTION public.inspecteur_mbti_create_session(p_inspecteur_id text, p_password text, p_nom text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_ok boolean;
  v_id text;
begin
  select exists(
    select 1 from inspecteurs where id = p_inspecteur_id and password = p_password and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return null; end if;

  v_id := 'mbt' || substr(md5(random()::text || clock_timestamp()::text), 1, 16);
  insert into mbti_sessions(id, inspecteur_id, nom) values (v_id, p_inspecteur_id, p_nom);
  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.inspecteur_mbti_delete_session(p_inspecteur_id text, p_password text, p_session_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = p_password) then
    return false;
  end if;
  delete from mbti_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id;
  return true;
end;
$function$;

CREATE OR REPLACE FUNCTION public.inspecteur_mbti_list_sessions(p_inspecteur_id text, p_password text)
 RETURNS SETOF mbti_sessions
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = p_password) then
    return;
  end if;
  return query select * from mbti_sessions where inspecteur_id = p_inspecteur_id order by created_at desc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.inspecteur_mbti_list_results(p_inspecteur_id text, p_password text, p_session_id text)
 RETURNS SETOF mbti_resultats
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = p_password) then
    return;
  end if;
  if not exists(select 1 from mbti_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id) then
    return;
  end if;
  return query select * from mbti_resultats where session_id = p_session_id order by created_at asc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.inspecteur_mbti_save_result(
  p_inspecteur_id text, p_password text, p_session_id text,
  p_nom text, p_prenom text, p_naissance text, p_classe text,
  p_scores jsonb, p_type_letters text, p_hierarchie jsonb, p_egalites jsonb
)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_ok boolean;
begin
  select exists(
    select 1 from inspecteurs where id = p_inspecteur_id and password = p_password and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return false; end if;

  if not exists(select 1 from mbti_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id) then
    return false;
  end if;

  insert into mbti_resultats(id, session_id, inspecteur_id, nom, prenom, naissance, classe, scores, type_letters, hierarchie, egalites)
  values (
    'mbtr' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
    p_session_id, p_inspecteur_id, p_nom, p_prenom, p_naissance, p_classe, p_scores, p_type_letters, p_hierarchie, coalesce(p_egalites, '[]'::jsonb)
  );
  return true;
end;
$function$;
