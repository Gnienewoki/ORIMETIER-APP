-- ============================================================
-- ORIMETIER — Fusion des doublons d'établissements — FICHIER 2 : MIGRATION.
--
-- ORDRE D'EXÉCUTION (SQL Editor de Supabase, un fichier à la fois, chacun EN ENTIER) :
--   1. fusion-doublons-etablissements-relecture.sql   lecture seule : 51 lignes, 18 « GARDÉE »,
--      33 « supprimée » ; relire les colonnes champs_completes et alertes ;
--   2. fusion-doublons-etablissements-1-test.sql      test à blanc : DOIT finir sur l'erreur
--      « TEST À BLANC RÉUSSI : tout a été annulé automatiquement (aucune donnée modifiée) » ;
--      toute autre erreur (ÉCHEC ..., GARDE ..., FUSION ...) = vrai échec : ne pas lancer le 2 ;
--   3. fusion-doublons-etablissements-2-migration.sql la fusion pour de bon, puis le tableau
--      (n, controle, ok) : TOUTES les lignes à true ;
--   4. à part, après vérification : DROP SCHEMA dbl_tmp CASCADE;
--
-- PAS DE BEGIN / COMMIT / ROLLBACK : le SQL Editor peut changer de connexion entre deux
-- instructions. Chaque bloc DO est atomique à lui seul : il est validé s'il va au bout,
-- entièrement annulé à la moindre exception. Les objets de travail sont dans le schéma
-- dbl_tmp (tables et fonctions normales, inaccessibles à anon/authenticated), recréé au
-- début de chaque fichier.
--
-- Source : Supabase Snippet Untitled query - 2026-10-05T173616.862.csv (31 groupes, 77 fiches)
-- + un 32e groupe trouvé par la normalisation (« œ ») : COLLEGE VICTOR SCHOELCHER YOPOUGON.
-- La base détecte 32 groupes. PÉRIMÈTRE TRAITÉ : 18 groupes (1 à 15 = supérieur/université,
-- 16 = EFTP Abengourou, 23, 25) = 51 fiches ; 18 gardées, 33 supprimées ; 4 204 - 33 = 4 171.
-- LAISSÉS DE CÔTÉ : les 14 autres groupes (17 à 22, 24, 26 à 32 = 28 fiches) : détectés,
-- jamais modifiés, contrôlés inchangés après la fusion (contrôle 12).
-- ESCA Abengourou : ignoré (absent en base).
--
-- CE FICHIER : partie 0 (schéma dbl_tmp recréé, état « avant » mesuré) puis UN SEUL bloc DO :
--   gardes ; fusion des 18 groupes traités ; exactement 33 suppressions ; les 12 contrôles. Le bloc
--   est validé seul s'il va au bout, annulé entièrement à la moindre exception.
--   Puis la requête finale (n, controle, ok) : toutes les lignes doivent valoir true.
-- DOUBLE EXÉCUTION IMPOSSIBLE : relancé après une fusion réussie, le bloc s'arrête sur la
--   garde « 4 204 fiches » (il n'en reste que 4 171) sans rien modifier ; la requête finale
--   affiche alors des false (journal vide) : c'est normal, la fusion a déjà eu lieu.
--
-- RÉFÉRENCES vers etablissements.id (diagnostic 5a-2f du 29/09 + revérifié ici) :
--   - AUCUNE clé étrangère (garde : arrêt s'il en apparaît une) ;
--   - liens logiques : sessions.user_id et password_resets.account_id (role = 'etablissement') ;
--   - filières, photos, logo, code de récupération : DANS la fiche (colonnes) ;
--   - eleves.etablissement et demandes_inscription_etablissements : liés par le NOM,
--     pas par l'id : rien à rattacher.
--
-- RÈGLE DE CHOIX de la fiche GARDÉE dans chaque groupe :
--   (a) la fiche réclamée (reclame = true) s'il y en a une ;
--   (a bis) sinon une fiche de catégorie 'superieur' ;
--   (b) sinon la plus complète : 1 point par champ non vide parmi region, quartier, type,
--       responsable, tel, tel2, tel3, email, site_web, contact_tel, logo_url, categorie,
--       sous_categorie, secteur, + 1 si filières, + 1 si photos ;
--   (c) sinon la plus ancienne (date_inscription JJ/MM/AAAA) ; enfin l'id (départage stable).
-- FUSION dans la fiche gardée :
--   - chaque champ texte VIDE est repris de la première autre fiche (dans l'ordre ci-dessus)
--     qui l'a rempli. JAMAIS email ni password (aucun compte créé ni modifié) ; le code de
--     récupération de la fiche gardée est conservé, ceux des fiches supprimées disparaissent ;
--   - filières : union sans doublon (nom + diplôme normalisés), celles de la fiche gardée
--     d'abord (toutes conservées), 10 au plus ;
--   - photos : celles de la fiche gardée, sinon les premières non vides des autres ;
--   - premium / demande_premium : vrai si une fiche du groupe l'était (rien de perdu) ;
--   - categorie, sous_categorie, secteur, statut : ceux de la fiche gardée (complétés
--     seulement s'ils sont vides). Les écarts sont listés par la requête de relecture.
-- RÉFÉRENCES des fiches supprimées : rattachées à la fiche gardée AVANT la suppression,
--   mais NEUTRALISÉES (sessions revoked = true, réinitialisations used = true) : une
--   session ouverte sur une fiche supprimée ne doit pas donner accès au compte gardé.
--   (En pratique 0 ligne : seule une fiche réclamée a des sessions, et une fiche
--   réclamée n'est jamais supprimée.)
-- ARRÊTS (rien n'est modifié) : nombre de fiches différent de 4 204 ; un id du CSV absent ;
--   un groupe dont les fiches n'ont pas la même ville + nom normalisés ; la détection en
--   base ne retrouve pas EXACTEMENT les 32 groupes (18 traités + 14 laissés) ; un groupe avec 2 fiches réclamées ou
--   plus ; le groupe EFTP Abengourou sans exactement 1 fiche réclamée ; une clé étrangère
--   vers etablissements.
-- ============================================================


-- ############################################################
-- PARTIE 0 : PRÉPARATION (schéma de travail dbl_tmp, aucune donnée de public modifiée)
-- ############################################################

DROP SCHEMA IF EXISTS dbl_tmp CASCADE;
CREATE SCHEMA dbl_tmp;
REVOKE ALL ON SCHEMA dbl_tmp FROM PUBLIC, anon, authenticated;

-- Normalisation (identique à la requête du CSV) : minuscules, sans accents, tout ce qui
-- n'est ni lettre ni chiffre est retiré ("ÉCOLE ... (EFTP)" = "ecole...eftp").
CREATE OR REPLACE FUNCTION dbl_tmp.dbl_norm(p_texte text)
 RETURNS text LANGUAGE sql IMMUTABLE
AS $function$
  select regexp_replace(
    translate(
      replace(replace(lower(coalesce(p_texte, '')), 'œ', 'oe'), 'æ', 'ae'),
      'àáâãäåāçćčèéêëēėęìíîïīñńòóôõöøōùúûüūýÿž',
      'aaaaaaaccceeeeeeeiiiiinnooooooouuuuuyyz'),
    '[^a-z0-9]+', '', 'g');
$function$;

CREATE OR REPLACE FUNCTION dbl_tmp.dbl_date(p_texte text)
 RETURNS date LANGUAGE sql IMMUTABLE
AS $function$
  select case when p_texte ~ '^\d{2}/\d{2}/\d{4}' then to_date(substr(p_texte, 1, 10), 'DD/MM/YYYY') end;
$function$;

CREATE OR REPLACE FUNCTION dbl_tmp.dbl_score(e public.etablissements)
 RETURNS integer LANGUAGE sql STABLE
AS $function$
  select (nullif(trim(e.region), '') is not null)::int
       + (nullif(trim(e.quartier), '') is not null)::int
       + (nullif(trim(e.type), '') is not null)::int
       + (nullif(trim(e.responsable), '') is not null)::int
       + (nullif(trim(e.tel), '') is not null)::int
       + (nullif(trim(e.tel2), '') is not null)::int
       + (nullif(trim(e.tel3), '') is not null)::int
       + (nullif(trim(e.email), '') is not null)::int
       + (nullif(trim(e.site_web), '') is not null)::int
       + (nullif(trim(e.contact_tel), '') is not null)::int
       + (nullif(trim(e.logo_url), '') is not null)::int
       + (nullif(trim(e.categorie), '') is not null)::int
       + (nullif(trim(e.sous_categorie), '') is not null)::int
       + (nullif(trim(e.secteur), '') is not null)::int
       + coalesce(jsonb_typeof(e.filieres_proposees) = 'array' and jsonb_array_length(e.filieres_proposees) > 0, false)::int
       + coalesce(jsonb_typeof(e.photos) = 'array' and jsonb_array_length(e.photos) > 0, false)::int;
$function$;

-- Première valeur non vide d'un champ parmi les fiches à supprimer (dans l'ordre de préférence)
CREATE OR REPLACE FUNCTION dbl_tmp.dbl_premier(p_autres jsonb, p_champ text)
 RETURNS text LANGUAGE sql IMMUTABLE
AS $function$
  select nullif(trim(x.v->>p_champ), '')
  from jsonb_array_elements(coalesce(p_autres, '[]'::jsonb)) with ordinality as x(v, pos)
  where nullif(trim(x.v->>p_champ), '') is not null
  order by x.pos
  limit 1;
$function$;

-- Les 18 groupes TRAITÉS (numéros de la liste d'origine : 1 à 15 = supérieur, 16 = EFTP
-- Abengourou, 23, 25) = 51 fiches.
CREATE TABLE dbl_tmp.dbl_reels (g integer NOT NULL, id text PRIMARY KEY);
INSERT INTO dbl_tmp.dbl_reels(g, id) VALUES
(1, 'id17863718536724937'),
(1, 'id17863719146330284'),
(1, 'id17863737136497232'),
(2, 'id178637185313738708'),
(2, 'id178637191413947426'),
(2, 'id178637371313536460'),
(3, 'id178637185314645073'),
(3, 'id178637191414708651'),
(3, 'id178637371314635674'),
(4, 'id178637185315556183'),
(4, 'id178637191415570615'),
(4, 'id178637371315923644'),
(5, 'id17863718531751346'),
(5, 'id178637191417208001'),
(5, 'id178637371317521713'),
(6, 'id17863718537823497'),
(6, 'id17863719147532947'),
(6, 'id17863737137717059'),
(7, 'id17863718538991065'),
(7, 'id17863719148890873'),
(7, 'id17863737138256111'),
(8, 'id17863718533729794'),
(8, 'id17863719143368957'),
(8, 'id17863737133997056'),
(9, 'id17863718534820041'),
(9, 'id17863719144636630'),
(9, 'id17863737134693043'),
(10, 'id17863718535978709'),
(10, 'id17863719145889831'),
(10, 'id17863737135441345'),
(11, 'id178637185310352297'),
(11, 'id178637191410393881'),
(11, 'id178637371310580710'),
(12, 'id178637185311852678'),
(12, 'id178637191411588709'),
(12, 'id178637371311268922'),
(13, 'id178637185312633457'),
(13, 'id178637191412859188'),
(13, 'id178637371312883748'),
(14, 'id17863718531683095'),
(14, 'id178637191416364877'),
(14, 'id178637371316839713'),
(15, 'id17863718539838433'),
(15, 'id17863719149770757'),
(15, 'id1786373713925750'),
(16, 'id178646268342615047'),
(16, 'idmshgvrozmdg0ny'),
(23, 'id178645177611338713'),
(23, 'id178645177617793548'),
(25, 'id1786462431124607493'),
(25, 'id1786462431126309453');

-- Les 14 groupes LAISSÉS DE CÔTÉ (17 à 22, 24, 26 à 32 = 28 fiches) : détectés en base, jamais
-- modifiés ; leur empreinte est relevée avant la fusion et recontrôlée après (contrôle 12).
CREATE TABLE dbl_tmp.dbl_laisses (g integer NOT NULL, id text PRIMARY KEY);
INSERT INTO dbl_tmp.dbl_laisses(g, id) VALUES
(17, 'id1786280870158430'),
(17, 'id178645177635666377'),
(18, 'id1786280979294289'),
(18, 'id178646285742903515'),
(19, 'id178628102190084'),
(19, 'id1786462683114862801'),
(20, 'id1786282468968306'),
(20, 'id1786451776115492855'),
(21, 'id1786282231661093'),
(21, 'id178645177634799438'),
(22, 'id17863762931956029'),
(22, 'id178646268395193822'),
(24, 'id1786282703816247'),
(24, 'id17864517761107012'),
(26, 'id1786281078575441'),
(26, 'id1786462683141305532'),
(27, 'id1786281078296148'),
(27, 'id1786462683132397530'),
(28, 'id1786281078865221'),
(28, 'id1786462683154835538'),
(29, 'id1786281078152176'),
(29, 'id1786462683155909624'),
(30, 'id1786281078764710'),
(30, 'id17864624311138534'),
(31, 'id1786282468403171'),
(31, 'id17864517764862381'),
(32, 'id1786281021713069'),
(32, 'id178646268315761760');

CREATE VIEW dbl_tmp.dbl_tous AS
  select r.g, r.id, true as traite from dbl_tmp.dbl_reels r
  union all
  select l.g, l.id, false from dbl_tmp.dbl_laisses l;

-- État AVANT la fusion (pour les contrôles finaux)
CREATE TABLE dbl_tmp.dbl_avant AS
select
  (select count(*) from public.etablissements)::int as total,
  (select count(*) from public.etablissements e where coalesce(e.reclame, false))::int as nb_reclamees,
  (select count(*) from public.sessions s
    where s.role = 'etablissement' and not exists (select 1 from public.etablissements e where e.id = s.user_id))::int as orph_sessions,
  (select count(*) from public.password_resets p
    where p.role = 'etablissement' and not exists (select 1 from public.etablissements e where e.id = p.account_id))::int as orph_resets;

-- Empreinte AVANT la fusion des 28 fiches laissées de côté (contrôle 12 : inchangées)
CREATE TABLE dbl_tmp.dbl_laisses_avant AS
select l.id, md5(to_jsonb(e)::text) as empreinte
from dbl_tmp.dbl_laisses l join public.etablissements e on e.id = l.id;

-- Journal de la fusion : une ligne par fiche traitée (gardée ou supprimée)
CREATE TABLE dbl_tmp.dbl_journal (
  groupe integer NOT NULL, id text NOT NULL, garde boolean NOT NULL, reclame boolean NOT NULL,
  avait_code boolean NOT NULL, nom text, ville text
);

CREATE OR REPLACE FUNCTION dbl_tmp.dbl_groupes_reels()
 RETURNS jsonb LANGUAGE sql STABLE
AS $function$
  select jsonb_agg(jsonb_build_object('g', s.g, 'ids', s.ids) order by s.g)
  from (select r.g, jsonb_agg(r.id order by r.id) as ids from dbl_tmp.dbl_reels r group by r.g) s;
$function$;

-- ------------------------------------------------------------
-- Gardes : lève une exception (rien n'est modifié) si la base n'est pas dans l'état attendu
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION dbl_tmp.dbl_gardes()
 RETURNS void LANGUAGE plpgsql
AS $function$
declare
  v_n integer; v_m integer; v_txt text;
begin
  select count(*) into v_n from public.etablissements;
  if v_n is distinct from 4204 then
    raise exception 'GARDE : % fiches dans etablissements au lieu de 4 204 (base modifiée depuis le CSV, ou fusion déjà faite). Rien n''est modifié.', v_n;
  end if;

  select count(*), count(distinct r.g) into v_n, v_m from dbl_tmp.dbl_reels r;
  if v_n is distinct from 51 or v_m is distinct from 18 then
    raise exception 'GARDE : liste des groupes traités incohérente (% ids, % groupes ; 51 et 18 attendus)', v_n, v_m;
  end if;
  select count(*), count(distinct l.g) into v_n, v_m from dbl_tmp.dbl_laisses l;
  if v_n is distinct from 28 or v_m is distinct from 14 then
    raise exception 'GARDE : liste des groupes laissés incohérente (% ids, % groupes ; 28 et 14 attendus)', v_n, v_m;
  end if;
  if exists (select 1 from dbl_tmp.dbl_reels r join dbl_tmp.dbl_laisses l on l.g = r.g or l.id = r.id) then
    raise exception 'GARDE : un groupe ou un id est à la fois traité et laissé de côté';
  end if;

  select string_agg(t.id, ', ') into v_txt from dbl_tmp.dbl_tous t
   where not exists (select 1 from public.etablissements e where e.id = t.id);
  if v_txt is not null then raise exception 'GARDE : id(s) de la liste (traités ou laissés) absent(s) de la base : %', v_txt; end if;

  select string_agg(s.g::text, ', ') into v_txt from (
    select t.g from dbl_tmp.dbl_tous t join public.etablissements e on e.id = t.id
    group by t.g
    having count(distinct dbl_tmp.dbl_norm(e.ville) || '|' || dbl_tmp.dbl_norm(e.nom)) > 1) s;
  if v_txt is not null then
    raise exception 'GARDE : groupe(s) % : fiches de ville + nom normalisés différents (normalisation différente de celle du CSV ?)', v_txt;
  end if;

  -- La détection en base doit retrouver EXACTEMENT les 32 groupes : 18 traités + 14 laissés
  with det as (
    select string_agg(e.id, ',' order by e.id) as ids
    from public.etablissements e
    where dbl_tmp.dbl_norm(e.nom) <> ''
    group by dbl_tmp.dbl_norm(e.ville), dbl_tmp.dbl_norm(e.nom)
    having count(*) > 1
  ), ref as (
    select string_agg(t.id, ',' order by t.id) as ids from dbl_tmp.dbl_tous t group by t.g
  )
  select (select count(*) from det),
         (select count(*) from det where det.ids not in (select ref.ids from ref))
                + (select count(*) from ref where ref.ids not in (select det.ids from det))
    into v_n, v_m;
  if v_n is distinct from 32 or v_m is distinct from 0 then
    raise exception 'GARDE : la détection en base trouve % groupe(s) de doublons, dont % différent(s) de la liste (32 identiques attendus : 18 traités + 14 laissés). Rien n''est modifié.', v_n, v_m;
  end if;

  select string_agg(s.g::text, ', ') into v_txt from (
    select r.g from dbl_tmp.dbl_reels r join public.etablissements e on e.id = r.id
    group by r.g having count(*) filter (where coalesce(e.reclame, false)) > 1) s;
  if v_txt is not null then
    raise exception 'GARDE : groupe(s) % : plusieurs fiches réclamées (deux comptes) : fusion refusée, à traiter à la main', v_txt;
  end if;

  select count(*) filter (where coalesce(e.reclame, false)),
         count(*) filter (where dbl_tmp.dbl_norm(e.ville) = 'abengourou'
                            and dbl_tmp.dbl_norm(e.nom) = 'ecoledeformationtechniqueetprofessionnelleeftpabengourou')
    into v_n, v_m
  from dbl_tmp.dbl_reels r join public.etablissements e on e.id = r.id where r.g = 16;
  if v_n is distinct from 1 or v_m is distinct from 2 then
    raise exception 'GARDE : groupe 16 (EFTP Abengourou) : % fiche(s) réclamée(s) sur % fiche(s) EFTP (1 sur 2 attendu)', v_n, v_m;
  end if;

  if exists (select 1 from pg_constraint c where c.contype = 'f' and c.confrelid = 'public.etablissements'::regclass) then
    raise exception 'GARDE : une clé étrangère pointe désormais vers etablissements : la fusion ne la rattacherait pas. Rien n''est modifié.';
  end if;

  -- Information seulement : colonnes dont le nom évoque un établissement
  for v_txt in
    select c.table_name || '.' || c.column_name from information_schema.columns c
    where c.table_schema = 'public' and c.table_name not in ('etablissements', 'demandes_inscription_etablissements')
      and c.column_name ilike '%etab%'
    order by 1
  loop
    raise notice 'Info : colonne % (liée par le nom, pas par l''id : non modifiée)', v_txt;
  end loop;
end; $function$;

-- ------------------------------------------------------------
-- Fusion d'une liste de groupes ([[id, id, ...], ...]) ; renvoie le nombre de fiches supprimées
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION dbl_tmp.dbl_fusionner(p_groupes jsonb)
 RETURNS integer LANGUAGE plpgsql
AS $function$
declare
  r record;
  v_ids text[]; v_ordre text[]; v_keep text; v_del text[];
  v_autres jsonb; v_fil jsonb; v_photos jsonb;
  v_premium boolean; v_dem boolean;
  v_n integer; v_total integer := 0;
begin
  -- p_groupes : [{"g": numéro du groupe, "ids": [id, ...]}, ...] (le numéro va au journal)
  for r in select x.val->'ids' as val, (x.val->>'g')::int as ord from jsonb_array_elements(p_groupes) as x(val) loop
    select array_agg(t.id order by t.id) into v_ids from jsonb_array_elements_text(r.val) as t(id);
    if coalesce(cardinality(v_ids), 0) < 2 then raise exception 'FUSION : groupe % de moins de 2 fiches', r.ord; end if;

    perform 1 from public.etablissements e where e.id = any(v_ids) for update;
    select count(*) into v_n from public.etablissements e where e.id = any(v_ids);
    if v_n is distinct from cardinality(v_ids) then raise exception 'FUSION : groupe % : fiche(s) absente(s) (%)', r.ord, v_ids; end if;

    select count(*) into v_n from public.etablissements e where e.id = any(v_ids) and coalesce(e.reclame, false);
    if v_n > 1 then
      raise exception 'FUSION : % fiches réclamées dans le groupe % (%) : fusion impossible', v_n, r.ord, v_ids;
    end if;

    -- Ordre de préférence : (a) réclamée, (b) catégorie superieur, (c) la plus complète,
    -- (d) la plus ancienne, puis l'id
    select array_agg(e.id order by coalesce(e.reclame, false) desc, coalesce(e.categorie = 'superieur', false) desc,
                                   dbl_tmp.dbl_score(e) desc,
                                   dbl_tmp.dbl_date(e.date_inscription) asc nulls last, e.id asc)
      into v_ordre
    from public.etablissements e where e.id = any(v_ids);
    v_keep := v_ordre[1];
    v_del := v_ordre[2:cardinality(v_ordre)];
    if exists (select 1 from public.etablissements e where e.id = any(v_del) and coalesce(e.reclame, false)) then
      raise exception 'FUSION : groupe % : une fiche réclamée serait supprimée', r.ord;
    end if;

    select jsonb_agg(to_jsonb(e) order by u.pos) into v_autres
    from unnest(v_del) with ordinality as u(id, pos) join public.etablissements e on e.id = u.id;

    -- Filières : union sans doublon (nom + diplôme normalisés), fiche gardée d'abord, 10 au plus
    select coalesce(jsonb_agg(z.val order by z.cle), '[]'::jsonb) into v_fil
    from (
      select s.val, s.cle from (
        select f.val, u.pos, (u.pos * 1000 + f.ord) as cle,
               row_number() over (partition by dbl_tmp.dbl_norm(f.val->>'nom'), dbl_tmp.dbl_norm(f.val->>'diplome')
                                  order by u.pos * 1000 + f.ord) as rn
        from unnest(v_ordre) with ordinality as u(id, pos)
        join public.etablissements e on e.id = u.id
        cross join lateral jsonb_array_elements(case when jsonb_typeof(e.filieres_proposees) = 'array'
                                                     then e.filieres_proposees else '[]'::jsonb end)
             with ordinality as f(val, ord)
      ) s
      where s.rn = 1 or s.pos = 1
      order by s.cle
      limit 10
    ) z;

    -- Photos : celles de la fiche gardée, sinon les premières non vides des autres
    select coalesce(
      (select e.photos from public.etablissements e
        where e.id = v_keep and jsonb_typeof(e.photos) = 'array' and jsonb_array_length(e.photos) > 0),
      (select x.v->'photos' from jsonb_array_elements(v_autres) with ordinality as x(v, pos)
        where jsonb_typeof(x.v->'photos') = 'array' and jsonb_array_length(x.v->'photos') > 0
        order by x.pos limit 1),
      (select e.photos from public.etablissements e where e.id = v_keep))
      into v_photos;

    select bool_or(coalesce(e.premium, false)), bool_or(coalesce(e.demande_premium, false))
      into v_premium, v_dem
    from public.etablissements e where e.id = any(v_ids);

    insert into dbl_tmp.dbl_journal(groupe, id, garde, reclame, avait_code, nom, ville)
    select r.ord, e.id, e.id = v_keep, coalesce(e.reclame, false), e.code_recuperation is not null, e.nom, e.ville
    from public.etablissements e where e.id = any(v_ids);

    update public.etablissements k set
      region         = coalesce(nullif(trim(k.region), ''),         dbl_tmp.dbl_premier(v_autres, 'region'),         k.region),
      quartier       = coalesce(nullif(trim(k.quartier), ''),       dbl_tmp.dbl_premier(v_autres, 'quartier'),       k.quartier),
      type           = coalesce(nullif(trim(k.type), ''),           dbl_tmp.dbl_premier(v_autres, 'type'),           k.type),
      responsable    = coalesce(nullif(trim(k.responsable), ''),    dbl_tmp.dbl_premier(v_autres, 'responsable'),    k.responsable),
      tel            = coalesce(nullif(trim(k.tel), ''),            dbl_tmp.dbl_premier(v_autres, 'tel'),            k.tel),
      tel2           = coalesce(nullif(trim(k.tel2), ''),           dbl_tmp.dbl_premier(v_autres, 'tel2'),           k.tel2),
      tel3           = coalesce(nullif(trim(k.tel3), ''),           dbl_tmp.dbl_premier(v_autres, 'tel3'),           k.tel3),
      site_web       = coalesce(nullif(trim(k.site_web), ''),       dbl_tmp.dbl_premier(v_autres, 'site_web'),       k.site_web),
      contact_tel    = coalesce(nullif(trim(k.contact_tel), ''),    dbl_tmp.dbl_premier(v_autres, 'contact_tel'),    k.contact_tel),
      logo_url       = coalesce(nullif(trim(k.logo_url), ''),       dbl_tmp.dbl_premier(v_autres, 'logo_url'),       k.logo_url),
      categorie      = coalesce(nullif(trim(k.categorie), ''),      dbl_tmp.dbl_premier(v_autres, 'categorie'),      k.categorie),
      sous_categorie = coalesce(nullif(trim(k.sous_categorie), ''), dbl_tmp.dbl_premier(v_autres, 'sous_categorie'), k.sous_categorie),
      secteur        = coalesce(nullif(trim(k.secteur), ''),        dbl_tmp.dbl_premier(v_autres, 'secteur'),        k.secteur),
      filieres_proposees = v_fil,
      photos = v_photos,
      premium = v_premium,
      demande_premium = (v_dem and not v_premium),
      demande_premium_date = coalesce(nullif(trim(k.demande_premium_date), ''), dbl_tmp.dbl_premier(v_autres, 'demande_premium_date'), k.demande_premium_date)
    where k.id = v_keep;

    -- Références : rattachées à la fiche gardée, mais neutralisées (cf. en-tête)
    update public.sessions s set user_id = v_keep, revoked = true
     where s.role = 'etablissement' and s.user_id = any(v_del);
    update public.password_resets p set account_id = v_keep, used = true
     where p.role = 'etablissement' and p.account_id = any(v_del);

    delete from public.etablissements e where e.id = any(v_del);
    get diagnostics v_n = row_count;
    if v_n is distinct from cardinality(v_del) then
      raise exception 'FUSION : groupe % : % fiche(s) supprimée(s) au lieu de %', r.ord, v_n, cardinality(v_del);
    end if;
    v_total := v_total + v_n;
  end loop;
  return v_total;
end; $function$;

-- ------------------------------------------------------------
-- Contrôles (utilisés par le test à blanc, par la migration avant COMMIT et par la partie 3)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION dbl_tmp.dbl_controles()
 RETURNS TABLE(n integer, controle text, ok boolean) LANGUAGE sql
AS $function$
  with av as (select * from dbl_tmp.dbl_avant),
  j as (select * from dbl_tmp.dbl_journal),
  sup as (select j.id from j where not j.garde),
  det as (
    select string_agg(e.id, ',' order by e.id) as ids from public.etablissements e
    where dbl_tmp.dbl_norm(e.nom) <> ''
    group by dbl_tmp.dbl_norm(e.ville), dbl_tmp.dbl_norm(e.nom)
    having count(*) > 1
  ),
  lais as (select string_agg(l.id, ',' order by l.id) as ids from dbl_tmp.dbl_laisses l group by l.g)
  select 1, 'doublons restants = exactement les 14 groupes laissés de côté (les 18 traités ont disparu)',
         (select count(*) = 14 from det) and not exists (select 1 from det where det.ids not in (select lais.ids from lais))
  union all select 2, 'nombre de fiches = 4 204 - 33 = 4 171',
         (select av.total = 4204 from av) and (select count(*) = 4171 from public.etablissements)
  union all select 3, 'fiche réclamée EFTP Abengourou : toujours là, seule de son nom, réclamée, gardée',
         (select count(*) = 1 and bool_and(coalesce(e.reclame, false)) from public.etablissements e
           where dbl_tmp.dbl_norm(e.ville) = 'abengourou'
             and dbl_tmp.dbl_norm(e.nom) = 'ecoledeformationtechniqueetprofessionnelleeftpabengourou')
         and exists (select 1 from j join public.etablissements e on e.id = j.id where j.groupe = 16 and j.garde and j.reclame)
  union all select 4, '18 fiches gardées présentes (une par groupe traité)',
         (select count(*) = 18 and count(distinct j.groupe) = 18 from j join public.etablissements e on e.id = j.id where j.garde)
  union all select 5, '33 fiches supprimées, plus aucune en base (leurs codes de récupération avec)',
         (select count(*) = 33 from sup) and not exists (select 1 from sup join public.etablissements e on e.id = sup.id)
  union all select 6, 'aucune fiche réclamée supprimée (même nombre de fiches réclamées qu''avant)',
         not exists (select 1 from j where not j.garde and j.reclame)
         and (select count(*) from public.etablissements e where coalesce(e.reclame, false)) = (select av.nb_reclamees from av)
  union all select 7, 'aucune session ni réinitialisation ne pointe vers une fiche supprimée',
         not exists (select 1 from public.sessions s join sup on sup.id = s.user_id where s.role = 'etablissement')
         and not exists (select 1 from public.password_resets p join sup on sup.id = p.account_id where p.role = 'etablissement')
  union all select 8, 'aucune nouvelle référence orpheline (orphelines déjà présentes avant : '
                      || (select av.orph_sessions from av) || ' session(s), ' || (select av.orph_resets from av) || ' réinitialisation(s))',
         (select count(*) from public.sessions s
           where s.role = 'etablissement' and not exists (select 1 from public.etablissements e where e.id = s.user_id))
           <= (select av.orph_sessions from av)
         and (select count(*) from public.password_resets p
           where p.role = 'etablissement' and not exists (select 1 from public.etablissements e where e.id = p.account_id))
           <= (select av.orph_resets from av)
  union all select 9, 'aucune clé étrangère vers etablissements (rien d''autre à rattacher)',
         not exists (select 1 from pg_constraint c where c.contype = 'f' and c.confrelid = 'public.etablissements'::regclass)
  union all select 10, 'fiches gardées : 10 filières au plus',
         not exists (select 1 from j join public.etablissements e on e.id = j.id
                      where j.garde and jsonb_typeof(e.filieres_proposees) = 'array' and jsonb_array_length(e.filieres_proposees) > 10)
  union all select 11, 'groupes 1 à 15 : la fiche gardée est superieur / universite',
         coalesce((select count(*) = 15 and bool_and(e.categorie = 'superieur' and e.sous_categorie = 'universite')
                     from j join public.etablissements e on e.id = j.id where j.garde and j.groupe between 1 and 15), false)
  union all select 12, 'les 28 fiches des 14 groupes laissés existent toujours, inchangées (ids et contenu)',
         (select count(*) = 28 from dbl_tmp.dbl_laisses_avant)
         and (select count(*) = 28 from dbl_tmp.dbl_laisses_avant la join public.etablissements e on e.id = la.id
               where md5(to_jsonb(e)::text) = la.empreinte)
$function$;


-- ############################################################
-- MIGRATION : un seul bloc DO (validé s'il va au bout, annulé sinon)
-- ############################################################

DO $$
declare
  v_n integer; v_txt text;
begin
  perform dbl_tmp.dbl_gardes();
  v_n := dbl_tmp.dbl_fusionner(dbl_tmp.dbl_groupes_reels());
  if v_n is distinct from 33 then raise exception 'ARRÊT : % fiche(s) supprimée(s) au lieu de 33 : fusion annulée', v_n; end if;
  select string_agg(c.n || '. ' || c.controle, ' | ' order by c.n) into v_txt from dbl_tmp.dbl_controles() c where c.ok is not true;
  if v_txt is not null then raise exception 'ARRÊT : contrôle(s) en échec, fusion annulée : %', v_txt; end if;
  raise notice 'Fusion : 33 fiches supprimées, 18 fiches gardées et complétées, 14 groupes laissés intacts';
end $$;


-- ############################################################
-- CONTRÔLE FINAL (dernière instruction : toutes les lignes = true)
-- ############################################################
select n, controle, ok from (
  select 0 as n, 'fusion validée par le bloc DO (51 fiches au journal)' as controle,
         (select count(*) = 51 from dbl_tmp.dbl_journal) as ok
  union all
  select c.n, c.controle, c.ok from dbl_tmp.dbl_controles() c
) t
order by n;

-- ############################################################
-- NETTOYAGE : à lancer À PART, seulement après avoir vérifié que toutes les lignes
-- ci-dessus valent true (la requête finale a besoin du schéma dbl_tmp) :
-- DROP SCHEMA dbl_tmp CASCADE;
-- ############################################################
