-- ============================================================
-- Messagerie privée (1-à-1) entre inspecteurs — façon WhatsApp
-- À exécuter dans Supabase > SQL Editor > New query > Run
-- ============================================================

create table if not exists messages_prives (
  id text primary key,
  expediteur_id text not null references inspecteurs(id),
  destinataire_id text not null references inspecteurs(id),
  texte text,
  date text,
  created_at timestamptz default now(),
  lu boolean default false,
  attachment_url text,
  attachment_type text,
  attachment_name text
);

-- Row Level Security activée, SANS policy publique : la table n'est accessible
-- à personne directement. Tout passe par les fonctions RPC ci-dessous, qui
-- vérifient le mot de passe et ne renvoient que les messages concernant
-- l'inspecteur connecté (jamais les conversations des autres).
alter table messages_prives enable row level security;

-- ---- Poster un message privé ----
create or replace function inspecteur_post_private_message(
  p_expediteur_id text, p_password text, p_destinataire_id text, p_texte text,
  p_attachment_url text default null, p_attachment_type text default null, p_attachment_name text default null
) returns boolean
language plpgsql security definer as $$
declare
  v_ok boolean;
begin
  select exists(
    select 1 from inspecteurs where id = p_expediteur_id and password = p_password and coalesce(banni,false) = false
  ) into v_ok;
  if not v_ok then return false; end if;

  if not exists(select 1 from inspecteurs where id = p_destinataire_id and coalesce(banni,false) = false) then
    return false;
  end if;

  insert into messages_prives(id, expediteur_id, destinataire_id, texte, date, attachment_url, attachment_type, attachment_name)
  values (
    'msg' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
    p_expediteur_id, p_destinataire_id, p_texte,
    to_char(now(), 'DD/MM/YYYY HH24:MI'),
    p_attachment_url, p_attachment_type, p_attachment_name
  );
  return true;
end;
$$;

-- ---- Lister mes messages privés (envoyés + reçus), jamais ceux des autres ----
create or replace function inspecteur_list_private_messages(p_inspecteur_id text, p_password text)
returns setof messages_prives
language plpgsql security definer as $$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = p_password) then
    return;
  end if;
  return query
    select * from messages_prives
    where expediteur_id = p_inspecteur_id or destinataire_id = p_inspecteur_id
    order by created_at asc;
end;
$$;

-- ---- Marquer comme lus les messages reçus d'un contact précis (compteur non-lu) ----
create or replace function inspecteur_mark_private_read(p_inspecteur_id text, p_password text, p_autre_id text)
returns boolean
language plpgsql security definer as $$
begin
  if not exists(select 1 from inspecteurs where id = p_inspecteur_id and password = p_password) then
    return false;
  end if;
  update messages_prives set lu = true
  where destinataire_id = p_inspecteur_id and expediteur_id = p_autre_id and lu = false;
  return true;
end;
$$;

grant execute on function inspecteur_post_private_message to anon;
grant execute on function inspecteur_list_private_messages to anon;
grant execute on function inspecteur_mark_private_read to anon;

notify pgrst, 'reload schema';
