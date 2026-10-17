-- ============================================================
-- Test LYCAM — sessions et résultats (espace inspecteur uniquement)
-- À exécuter dans Supabase > SQL Editor > New query > Run
-- ============================================================

create table if not exists lycam_sessions (
  id text primary key,
  inspecteur_id text not null references inspecteurs(id),
  nom text not null,
  created_at timestamptz default now()
);

create table if not exists lycam_resultats (
  id text primary key,
  session_id text not null references lycam_sessions(id) on delete cascade,
  inspecteur_id text not null references inspecteurs(id),
  nom text,
  prenom text,
  naissance text,
  classe text,
  score_total integer not null,
  band text not null,
  scores jsonb not null,
  created_at timestamptz default now()
);

-- RLS activée, sans policy publique : tout passe par les fonctions RPC ci-dessous,
-- qui vérifient le mot de passe et ne renvoient que les sessions/résultats
-- appartenant à l'inspecteur connecté (jamais ceux d'un autre inspecteur).
alter table lycam_sessions enable row level security;
alter table lycam_resultats enable row level security;

-- ---- Créer une nouvelle session (ex : une classe, ou un test ponctuel) ----
create or replace function inspecteur_lycam_create_session(
  p_inspecteur_id text, p_password text, p_nom text
) returns text
language plpgsql security definer as $$
declare
  v_ok boolean;
  v_id text;
begin
  select exists(
    select 1 from inspecteurs where id = p_inspecteur_id and password = p_password and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return null; end if;

  v_id := 'lyc' || substr(md5(random()::text || clock_timestamp()::text), 1, 16);
  insert into lycam_sessions(id, inspecteur_id, nom) values (v_id, p_inspecteur_id, p_nom);
  return v_id;
end;
$$;

-- ---- Enregistrer le résultat d'un élève testé dans une session ----
create or replace function inspecteur_lycam_save_result(
  p_inspecteur_id text, p_password text, p_session_id text,
  p_nom text, p_prenom text, p_naissance text, p_classe text,
  p_score_total integer, p_band text, p_scores jsonb
) returns boolean
language plpgsql security definer as $$
declare
  v_ok boolean;
begin
  select exists(
    select 1 from inspecteurs where id = p_inspecteur_id and password = p_password and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return false; end if;

  if not exists(select 1 from lycam_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id) then
    return false;
  end if;

  insert into lycam_resultats(id, session_id, inspecteur_id, nom, prenom, naissance, classe, score_total, band, scores)
  values (
    'lycr' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
    p_session_id, p_inspecteur_id, p_nom, p_prenom, p_naissance, p_classe, p_score_total, p_band, p_scores
  );
  return true;
end;
$$;

-- ---- Lister mes sessions (jamais celles d'un autre inspecteur) ----
create or replace function inspecteur_lycam_list_sessions(p_inspecteur_id text, p_password text)
returns setof lycam_sessions
language plpgsql security definer as $$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = p_password) then
    return;
  end if;
  return query select * from lycam_sessions where inspecteur_id = p_inspecteur_id order by created_at desc;
end;
$$;

-- ---- Lister les résultats d'une de mes sessions ----
create or replace function inspecteur_lycam_list_results(p_inspecteur_id text, p_password text, p_session_id text)
returns setof lycam_resultats
language plpgsql security definer as $$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = p_password) then
    return;
  end if;
  if not exists(select 1 from lycam_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id) then
    return;
  end if;
  return query select * from lycam_resultats where session_id = p_session_id order by created_at asc;
end;
$$;

-- ---- Supprimer une de mes sessions (et ses résultats, en cascade) ----
create or replace function inspecteur_lycam_delete_session(p_inspecteur_id text, p_password text, p_session_id text)
returns boolean
language plpgsql security definer as $$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = p_password) then
    return false;
  end if;
  delete from lycam_sessions where id = p_session_id and inspecteur_id = p_inspecteur_id;
  return true;
end;
$$;

grant execute on function inspecteur_lycam_create_session to anon;
grant execute on function inspecteur_lycam_save_result to anon;
grant execute on function inspecteur_lycam_list_sessions to anon;
grant execute on function inspecteur_lycam_list_results to anon;
grant execute on function inspecteur_lycam_delete_session to anon;

notify pgrst, 'reload schema';
