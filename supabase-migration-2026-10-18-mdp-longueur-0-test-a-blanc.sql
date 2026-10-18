-- ============================================================
-- ORIMETIER — Longueur minimale des mots de passe (phase 8) : FICHIER 0, TEST À BLANC.
-- LECTURE SEULE : une seule requête SELECT, rien n'est écrit. À lancer AVANT A.
-- Me renvoyer le résultat complet (colonnes n, verification, valeur, attendu).
--
-- A ne réécrit AUCUN corps de fonction à la main : il lit la définition en production
-- (pg_get_functiondef), y insère le contrôle à un endroit précis repéré par un passage
-- exact, puis la réinstalle. Ce test vérifie donc surtout que chaque passage repère est
-- présent UNE fois exactement dans la définition en production.
-- ============================================================

with cible(n, sig, mode, ancre) as (values
  (1, 'public.inspecteur_register(text,text,text,text,text,text,text,text,text)', 'regex',
      $r$'erreur', 'CHAMPS_OBLIGATOIRES'\);\s*end if;$r$),
  (2, 'public.etablissement_claim_v2(text,text,text,text,text,text,text,text,text,text)', 'regex',
      $r$'erreur', 'CHAMPS_OBLIGATOIRES'\);\s*end if;$r$),
  (3, 'public.etablissement_register(text,text,text,text,text,text,text,text,text,text,text,jsonb,jsonb,text,text,text,text,text,text,text,text)', 'texte',
      $a$if p_password is null or length(trim(p_password)) = 0 then return false; end if;$a$),
  (4, 'public.reset_password_with_token(text,text)', 'texte',
      $a$if p_new_password is null or length(p_new_password) < 4 or p_new_password ~ '^\$2[aby]\$' then$a$)
),
f as (
  select c.n, c.sig, c.mode, c.ancre, to_regprocedure(c.sig) as oid,
         case when to_regprocedure(c.sig) is not null then pg_get_functiondef(to_regprocedure(c.sig)) end as def
  from cible c
),
lignes as (
  -- Par fonction à corriger : présence, retour, passage repère, déjà corrigée ?, propriétaire, droits
  select f.n * 10 + 1 as n, split_part(f.sig, '(', 1) || ' : présente, retour' as verification,
         coalesce(pg_get_function_result(f.oid), 'ABSENTE') as valeur,
         case when f.n <= 2 then 'jsonb' else 'boolean' end as attendu
  from f
  union all
  select f.n * 10 + 2, split_part(f.sig, '(', 1) || ' : passage repère trouvé (fois)',
         case when f.def is null then '—'
              when f.mode = 'regex' then (select count(*) from regexp_matches(f.def, f.ancre, 'g'))::text
              else ((length(f.def) - length(replace(f.def, f.ancre, ''))) / length(f.ancre))::text end,
         '1 (ou 0 si la ligne suivante vaut true)'
  from f
  union all
  select f.n * 10 + 3, split_part(f.sig, '(', 1) || ' : déjà corrigée (cite MOT_DE_PASSE_TROP_COURT)',
         coalesce((position('MOT_DE_PASSE_TROP_COURT' in f.def) > 0)::text, '—'), 'false'
  from f
  union all
  select f.n * 10 + 4, split_part(f.sig, '(', 1) || ' : SECURITY DEFINER / propriétaire / EXECUTE anon',
         coalesce((select p.prosecdef::text || ' / ' || pg_get_userbyid(p.proowner) || ' / '
                          || has_function_privilege('anon', p.oid, 'EXECUTE')::text
                   from pg_proc p where p.oid = f.oid), '—'),
         'true / (utilisateur de la ligne 1) / true'
  from f
  union all
  select f.n * 10 + 5, split_part(f.sig, '(', 1) || ' : surcharges de ce nom dans public',
         (select count(*)::text from pg_proc p join pg_namespace s on s.oid = p.pronamespace
          where s.nspname = 'public' and p.proname = split_part(split_part(f.sig, '(', 1), '.', 2)),
         '1'
  from f
  union all
  select f.n * 10 + 6, split_part(f.sig, '(', 1) || ' : empreinte md5 du corps (pour mémoire)',
         coalesce((select md5(p.prosrc) from pg_proc p where p.oid = f.oid), '—'), '(information)'
  from f
  -- Contexte
  union all
  select 1, 'utilisateur courant (doit être propriétaire des 4 fonctions pour les remplacer)',
         current_user::text, 'postgres en général'
  union all
  select 2, 'reset_password_with_token : branche ''eleve'' encore présente (étape e de la suppression élève non lancée)',
         coalesce((select (position('''eleve''' in pg_get_functiondef(p.oid)) > 0)::text from pg_proc p
                   where p.oid = to_regprocedure('public.reset_password_with_token(text,text)')), '—'),
         'true ou false : les deux conviennent'
  -- Comptes admin : contrôle déjà en place (non modifiés par A)
  union all
  select 3, 'admin_create_admin_v2 : refuse déjà < 8 (MOT_DE_PASSE_TROP_COURT)',
         coalesce((select (position('< 8' in pg_get_functiondef(p.oid)) > 0
                           and position('MOT_DE_PASSE_TROP_COURT' in pg_get_functiondef(p.oid)) > 0)::text
                   from pg_proc p where p.oid = to_regprocedure('public.admin_create_admin_v2(text,text,text,text)')), 'ABSENTE'),
         'true'
  union all
  select 4, 'admin_change_password_v2 : refuse déjà < 8 (MOT_DE_PASSE_TROP_COURT)',
         coalesce((select (position('< 8' in pg_get_functiondef(p.oid)) > 0
                           and position('MOT_DE_PASSE_TROP_COURT' in pg_get_functiondef(p.oid)) > 0)::text
                   from pg_proc p where p.oid = to_regprocedure('public.admin_change_password_v2(text,text,text)')), 'ABSENTE'),
         'true'
  -- Connexion : aucune fonction d'ouverture de session ne contrôle la longueur (rien à changer)
  union all
  select 5, 'fonctions *_session_open qui contrôlent une longueur de mot de passe',
         coalesce((select string_agg(p.proname, ', ' order by p.proname) from pg_proc p
                   join pg_namespace s on s.oid = p.pronamespace
                   where s.nspname = 'public' and p.proname like '%session_open%'
                     and p.prosrc ~* 'length\s*\(\s*(coalesce\s*\()?\s*p_password'), 'aucune'),
         'aucune'
  -- Tous les chemins d'écriture d'un mot de passe (UPDATE … SET … password = / INSERT … (… password …))
  union all
  select 6, 'fonctions public qui écrivent une colonne password ((anon) = exécutable par la clé publique)',
         coalesce((select string_agg(p.proname || case when has_function_privilege('anon', p.oid, 'EXECUTE') then ' (anon)' else '' end,
                                     ', ' order by p.proname)
                   from pg_proc p join pg_namespace s on s.oid = p.pronamespace
                   where s.nspname = 'public'
                     and p.prosrc ~* '(update\s+\w+(\s+\w+)?\s+set\s[^;]*\mpassword\s*=|insert\s+into\s+\w+\s*\([^)]*\mpassword\M)'), 'aucune'),
         'admin_change_password_v2 (anon), admin_create_admin_v2 (anon), admin_refuser_demande_v2 (anon), admin_valider_demande_v2 (anon), etablissement_claim_v2 (anon), etablissement_register (anon), inspecteur_register (anon), reset_password_with_token (anon) ; éventuellement d''anciennes fonctions SANS (anon) ; toute autre fonction marquée (anon) : me l''envoyer'
)
select n, verification, valeur, attendu from lignes order by n;
