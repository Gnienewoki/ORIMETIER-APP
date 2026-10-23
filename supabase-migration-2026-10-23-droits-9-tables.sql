-- ============================================================
-- ORIMETIER — Phase 8 : retrait des droits en trop sur 9 tables (exécuté en production le 2026-10-23).
--
-- ÉTAT AVANT (audit du 2026-10-23) : RLS active sur les 9 tables ; 7 tables avec une règle
-- « Lecture publique » (SELECT, anon + authenticated) ; activation_codes et visites sans aucune
-- règle ; mais TOUS les droits (SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER)
-- accordés à anon et authenticated sur les 9.
--
-- VÉRIFIÉ AVANT : le site (*.js, *.html) n'écrit jamais directement dans ces tables et ne lit
-- jamais directement visites ni activation_codes (écritures et statistiques passent par des
-- fonctions SECURITY DEFINER, non concernées par ces droits).
--
-- APRÈS :
--   - annonce, debouches_filieres, grande_ecole_filieres, grandes_ecoles, liens_formation,
--     universite_filieres, universites : lecture seule (SELECT) pour anon et authenticated ;
--   - activation_codes, visites : aucun accès direct pour anon et authenticated.
--
-- Fichier à lancer EN ENTIER, sans rien sélectionner. Bloc DO atomique (gardes, contrôles
-- internes), puis requête de vérification (attendu : 9 lignes, ok = true).
-- Retour arrière : bloc commenté en fin de fichier.
-- ============================================================

DO $migration$
declare
  v_pub  text[] := array['annonce','debouches_filieres','grande_ecole_filieres','grandes_ecoles','liens_formation','universite_filieres','universites'];
  v_priv text[] := array['activation_codes','visites'];
  t text;
begin
  -- GARDES : la base doit être dans l'état audité, sinon arrêt sans rien modifier
  foreach t in array v_pub || v_priv loop
    if to_regclass('public.' || t) is null then
      raise exception 'GARDE : table % absente : rien n''est modifié.', t;
    end if;
    if not (select c.relrowsecurity from pg_class c where c.oid = to_regclass('public.' || t)) then
      raise exception 'GARDE : RLS inactive sur % : rien n''est modifié.', t;
    end if;
    if not pg_has_role(current_user, (select c.relowner from pg_class c where c.oid = to_regclass('public.' || t)), 'MEMBER') then
      raise exception 'GARDE : % appartient à un autre rôle : rien n''est modifié.', t;
    end if;
  end loop;
  foreach t in array v_pub loop
    if not exists (select 1 from pg_policies p
                   where p.schemaname = 'public' and p.tablename = t and p.cmd = 'SELECT' and p.roles @> array['anon']::name[]) then
      raise exception 'GARDE : pas de règle de lecture publique sur % : rien n''est modifié.', t;
    end if;
  end loop;

  -- 7 tables publiques : on garde uniquement la lecture
  foreach t in array v_pub loop
    execute format('revoke insert, update, delete, truncate, references, trigger on table public.%I from public, anon, authenticated', t);
    execute format('grant select on table public.%I to anon, authenticated', t);
  end loop;

  -- 2 tables internes : aucun accès direct (elles passent par des fonctions sécurisées)
  foreach t in array v_priv loop
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
  end loop;

  -- CONTRÔLES internes (une exception annule tout)
  foreach t in array v_pub loop
    if not has_table_privilege('anon', 'public.' || t, 'SELECT') or not has_table_privilege('authenticated', 'public.' || t, 'SELECT') then
      raise exception 'ÉCHEC : lecture perdue sur % : tout est annulé.', t;
    end if;
    if has_table_privilege('anon', 'public.' || t, 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       or has_table_privilege('authenticated', 'public.' || t, 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER') then
      raise exception 'ÉCHEC : droits d''écriture encore présents sur % : tout est annulé.', t;
    end if;
  end loop;
  foreach t in array v_priv loop
    if has_table_privilege('anon', 'public.' || t, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
       or has_table_privilege('authenticated', 'public.' || t, 'SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER') then
      raise exception 'ÉCHEC : droits encore présents sur % : tout est annulé.', t;
    end if;
  end loop;
  raise notice 'Droits retirés sur les 9 tables.';
end;
$migration$;

-- Vérification finale : attendu 9 lignes, ok = true partout
select c.relname as "table",
       has_table_privilege('anon', c.oid, 'SELECT') as anon_lecture,
       has_table_privilege('anon', c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER') as anon_autres,
       has_table_privilege('authenticated', c.oid, 'SELECT') as auth_lecture,
       has_table_privilege('authenticated', c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER') as auth_autres,
       case when c.relname in ('activation_codes', 'visites')
            then not (has_table_privilege('anon', c.oid, 'SELECT') or has_table_privilege('authenticated', c.oid, 'SELECT')
                      or has_table_privilege('anon', c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
                      or has_table_privilege('authenticated', c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER'))
            else (has_table_privilege('anon', c.oid, 'SELECT') and has_table_privilege('authenticated', c.oid, 'SELECT')
                  and not has_table_privilege('anon', c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER')
                  and not has_table_privilege('authenticated', c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER'))
       end as ok
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('activation_codes','annonce','debouches_filieres','grande_ecole_filieres','grandes_ecoles',
                    'liens_formation','universite_filieres','universites','visites')
order by 1;

-- ============================================================
-- RETOUR ARRIÈRE (NE PAS LANCER sauf besoin) : remet exactement l'ancien état (tous les droits).
-- Retirer les « -- » de début de ligne, puis coller seul dans le SQL Editor.
-- ============================================================
-- grant all on table public.activation_codes, public.annonce, public.debouches_filieres,
--   public.grande_ecole_filieres, public.grandes_ecoles, public.liens_formation,
--   public.universite_filieres, public.universites, public.visites to anon, authenticated;
