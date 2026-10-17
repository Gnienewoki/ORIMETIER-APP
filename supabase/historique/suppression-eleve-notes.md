# Suppression du compte élève — étapes c, d, e, f (base et Edge Function)

- Date : 2026-10-17. Front sans compte élève déjà en production (commit `b969c96`, service worker v34).
- Décision prise : les comptes élèves existants et le seul résultat RIASEC sont supprimés **sans archive**.
- Rien n'a été exécuté. Tous les fichiers sont à lancer **par toi**, dans l'ordre ci-dessous.

## Fichiers livrés

| Fichier | Rôle | Réversible ? |
|---|---|---|
| `index-sans-eleve.ts` | Edge Function `request-password-reset` sans le rôle élève (étape c) | oui (redéployer l'ancienne) |
| `supabase-migration-2026-10-17-suppression-eleve-0-test-a-blanc.sql` | Test à blanc, une seule requête, lecture seule | — |
| `supabase-migration-2026-10-17-suppression-eleve-d.sql` | Coupe tous les accès publics (droits, policies), sans rien supprimer | **oui** (bloc commenté en fin de fichier) |
| `supabase-migration-2026-10-17-suppression-eleve-e.sql` | Supprime les 5 fonctions élève, adapte 3 fonctions, retire le rôle `eleve` | oui, en recréant (voir plus bas) |
| `supabase-migration-2026-10-17-suppression-eleve-f.sql` | Supprime les tables `eleves` et `notes` | **NON** |
| `supabase-migration-2026-10-17-suppression-eleve-controle.sql` | 4 requêtes de contrôle (après c, d, e, f), lecture seule | — |

Chaque fichier de migration (d, e, f) tient dans **une transaction** et commence par des **garde-fous**. Si une condition n'est pas remplie, il s'arrête avec un message clair, et rien n'est appliqué.

---

## Ordre d'exécution exact

### 0 — Test à blanc (lecture seule)
1. Lancer `…-0-test-a-blanc.sql` en entier.
2. **M'envoyer le résultat complet.** Les points bloquants :
   - les 5 lignes `fonction_a_adapter` doivent valoir « IDENTIQUE au dépôt ». Sinon, ne pas aller plus loin : exporter la définition (requête en annexe B) et me l'envoyer ;
   - `cle_etrangere_vers` : au plus `notes -> eleves` ;
   - `vue` : aucune ligne ;
   - `fonction_utilise_table` et `fonction_eleve` : seulement les fonctions annoncées en tête du fichier.
3. Noter les lignes `droit_table` : elles servent au retour arrière de l'étape d.

### c — Edge Function (sans toucher à la base)
1. Copier `index-sans-eleve.ts` **à la place de** `supabase/functions/request-password-reset/index.ts` dans le dépôt. Le fichier est en fins de ligne LF, comme l'original.
2. Redéployer, au choix :
   - **CLI (le dépôt contient `package.json` avec la CLI `supabase` et `supabase/config.toml`)**, depuis la racine du dépôt :
     ```
     npx supabase login
     npx supabase functions deploy request-password-reset --project-ref ltfxaxzkuyejcluoaimq --no-verify-jwt
     ```
     `npx supabase login` n'est nécessaire qu'une fois par poste. `--no-verify-jwt` correspond à `[functions.request-password-reset] verify_jwt = false` de `config.toml`, qui est indispensable : la clé publique `sb_publishable_…` n'est pas un JWT. Les secrets (APP_URL, EMAILJS_…) déjà définis sont conservés.
   - **Tableau de bord** : Edge Functions → `request-password-reset` → onglet Code → coller le contenu de `index-sans-eleve.ts` → Deploy. Vérifier ensuite dans les réglages de la fonction que **« Verify JWT » est désactivé**.
3. **Tests** (voir « Tests de l'Edge Function » ci-dessous), puis la requête de contrôle « APRÈS c ».
4. **Retour arrière** : redéployer l'ancienne version (`git show b969c96:supabase/functions/request-password-reset/index.ts`), avec la même commande.

### d — Couper les accès (réversible)
1. Lancer `…-d.sql`.
2. Lancer la requête de contrôle « APRÈS d » : 19 lignes, `ok = true`.
3. **Tests du site** : voir « Batterie de tests ». Rien ne doit avoir changé pour les visiteurs, inspecteurs, établissements et l'admin.
4. **Retour arrière** : le bloc commenté en fin de `…-d.sql`, à coller tel quel, ajusté au besoin d'après les lignes `droit_table` du test à blanc 0.

**Remarque** : l'étape d coupe aussi la lecture publique de la table `notes` et sa policy « lecture notes ». Ce n'était pas dans ta liste, mais cette table ne contient que des notes sur des élèves inscrits, elle est lisible par tous, et le front ne la lit plus depuis `b969c96`.

### e — Fonctions et rôle `eleve`
1. Lancer `…-e.sql`. Ses garde-fous vérifient que l'étape d est faite, que les 3 fonctions réécrites sont identiques au dépôt (empreinte md5) et qu'aucune autre fonction n'utilise `eleves`.
2. Lancer la requête de contrôle « APRÈS e » : 17 lignes, `ok = true`.
3. **Tests du site** : batterie complète, en insistant sur la connexion et la réinitialisation de mot de passe d'un **inspecteur** et d'un **établissement**, et sur la connexion **admin**. Ce sont elles qui passent par les fonctions réécrites.
4. Faire le **test de la session élève encore ouverte**, partie serveur (plus bas).
5. **Retour arrière** : voir « Retour arrière de l'étape e ».

**Délai conseillé avant l'étape f** : quelques jours d'usage normal, pour s'assurer qu'aucune fonction oubliée ne lit `eleves`. Elle échouerait alors avec « relation eleves does not exist » après l'étape f.

### f — Tables (IRRÉVERSIBLE)
1. Lancer `…-f.sql`. Son bloc de garde échoue avant toute suppression dans quatre cas : étape e non faite, clé étrangère imprévue, vue, fonction qui utilise encore `eleves` ou `notes`, ou toute autre dépendance.
2. Lancer la requête de contrôle « APRÈS f » : 7 lignes, `ok = true`.
3. **Tests du site** : batterie complète.
4. **Pas de retour arrière** : sans archive, les données sont perdues. Seule la structure pourrait être recréée.

---

## Batterie de tests (après d, e et f)

À faire dans un navigateur, en navigation privée pour les visiteurs, avec la console ouverte (aucune erreur rouge attendue) :

1. **Visiteur** : accueil, puis Technique, Général, Supérieur, Concours, Formations ; test de personnalité complet, puis « Télécharger mon profil (PDF) ».
2. **Menu « Ouvrir un compte »** : Inspecteur d'orientation et Établissement, avec leurs infobulles. **Portail** `espaces.html` : 3 cartes.
3. **Inspecteur** : connexion, suivi d'élèves (ajout, note, suppression d'une fiche de test), LYCAM et MBTI (ouvrir une session), messages, déconnexion.
4. **Établissement** : connexion, tableau de bord, modification d'un champ sans conséquence, déconnexion.
5. **Admin** : connexion, vue d'ensemble, Établissements, Statistiques de visites, Exporter une sauvegarde, déconnexion.
6. **Mot de passe oublié** : la liste propose Inspecteur et Établissement. Faire une demande pour un compte de test inspecteur : l'e-mail arrive, le lien fonctionne, le nouveau mot de passe permet de se connecter.
7. **Onglet Réseau** : aucun appel à `list_eleves`, `eleve_*` ni `/rest/v1/notes`.

## Tests de l'Edge Function (après c)

Depuis Git Bash. La clé publique est celle de `supabase-config.js` (constante `SUPABASE_ANON_KEY`). Utiliser une adresse de test **inventée** (domaine `.invalid`) : jamais l'adresse d'une vraie personne.

```
URL="https://ltfxaxzkuyejcluoaimq.supabase.co/functions/v1/request-password-reset"
CLE="<valeur de SUPABASE_ANON_KEY dans supabase-config.js>"

# 1. Rôle élève : attendu HTTP 200 et {"ok":true}, sans délai particulier
curl -s -i -X POST "$URL" -H "Content-Type: application/json" -H "apikey: $CLE" \
  -d '{"role":"eleve","email":"compte-test@exemple.invalid"}'

# 2. Rôle inspecteur, e-mail sans compte : attendu exactement la même réponse que 1
curl -s -i -X POST "$URL" -H "Content-Type: application/json" -H "apikey: $CLE" \
  -d '{"role":"inspecteur","email":"compte-test@exemple.invalid"}'

# 3. Rôle inconnu : attendu HTTP 400 et {"ok":false} (comportement inchangé)
curl -s -i -X POST "$URL" -H "Content-Type: application/json" -H "apikey: $CLE" \
  -d '{"role":"inconnu","email":"compte-test@exemple.invalid"}'
```

Ensuite, lancer la requête de contrôle « APRÈS c » : 0 réinitialisation de rôle élève créée. Dans les journaux de la fonction (tableau de bord → Edge Functions → Logs), le test 1 ne doit produire **aucune** ligne.

## Test d'une session élève encore ouverte

**Partie navigateur** (possible dès maintenant, puisque le front v34 est en production) :
1. Ouvrir `espaces.html`, puis la console (F12) et coller :
   ```
   localStorage.setItem('GNK_ESPACES_SESSION', JSON.stringify({v:2, role:'eleve', id:'test', token:'jeton-de-test', exp: Date.now() + 86400000})); location.reload();
   ```
2. **Attendu** :
   - pas d'affichage furtif de l'espace privé : le portail s'affiche directement ;
   - aucune alerte ni erreur dans la console ;
   - la clé `GNK_ESPACES_SESSION` a disparu (`localStorage.getItem('GNK_ESPACES_SESSION')` renvoie `null`) ;
   - l'onglet Réseau montre un appel `rpc/session_close`, dont la réponse `false` est normale pour ce faux jeton.
3. Recommencer sur une page publique (`technique.html`) : la page s'affiche en mode visiteur, et la clé disparaît aussi.

**Partie serveur** (après l'étape e). Lancer dans le SQL Editor ; la transaction est annulée et rien n'est écrit :
```
BEGIN;
INSERT INTO public.sessions(token_hash, role, user_id, expires_at)
VALUES (encode(extensions.digest('jeton-test-eleve', 'sha256'), 'hex'), 'eleve', 'test', now() + interval '1 hour');
ROLLBACK;
```
**Attendu** : une erreur `violates check constraint "sessions_role_check"`. Aucune session élève ne peut plus exister.

Un vrai élève resté connecté sur un appareil :
- son jeton a été supprimé de `sessions` à l'étape e, donc `session_check` renvoie `null` ;
- le front v34 a de toute façon effacé sa session au premier chargement ;
- même si une ligne avait survécu, la liste blanche de `_session_user` la refuserait.

---

## Retour arrière de l'étape e

Il se fait dans une transaction, en collant dans le SQL Editor, dans cet ordre :

1. **Contraintes CHECK d'origine** :
   ```
   ALTER TABLE public.sessions DROP CONSTRAINT sessions_role_check;
   ALTER TABLE public.sessions ADD CONSTRAINT sessions_role_check CHECK (role IN ('eleve', 'inspecteur', 'etablissement', 'admin'));
   ALTER TABLE public.password_resets DROP CONSTRAINT password_resets_role_check;
   ALTER TABLE public.password_resets ADD CONSTRAINT password_resets_role_check CHECK (role IN ('eleve', 'inspecteur', 'etablissement'));
   ```
2. **Les 3 fonctions réécrites**, en version AVANT : les blocs `CREATE OR REPLACE` de l'annexe A, section AVANT, suivis de leurs `REVOKE` / `GRANT`, identiques à ceux de l'étape e.
3. **Les 5 fonctions supprimées**, depuis le dépôt :
   - `eleve_session_open`, `eleve_save_riasec`, `eleve_update_email` : `supabase-migration-2026-09-26-sessions-2a-eleve.sql`, blocs des lignes 47 à 162, avec leurs `REVOKE` / `GRANT` ;
   - `admin_set_eleve_banni_v2` : `supabase-migration-2026-09-29-admins-5a-2a-utilisateurs.sql`, lignes 41 à 54 ;
   - `list_eleves` : `supabase-list-functions.sql`, lignes 12 à 20, puis `GRANT EXECUTE ON FUNCTION public.list_eleves() TO anon, authenticated;` si l'étape d est aussi annulée.
4. Les sessions et réinitialisations de rôle élève supprimées **ne se restaurent pas**. C'est sans conséquence : les élèves devraient simplement se reconnecter, si le front était remis.

Ce retour n'est possible que **tant que l'étape f n'a pas été lancée** (les fonctions ont besoin de la table `eleves`).

---

## Annexe A — Corps complets AVANT / APRÈS des fonctions adaptées

Source AVANT : dernières versions versionnées dans le dépôt. La migration e vérifie, par empreinte md5, que la production est identique avant d'écrire quoi que ce soit.

### A.1 `_session_user(p_token text, p_role text)` — `supabase-migration-2026-09-28-admins-5a-1-session.sql`, lignes 44-94

**AVANT**
```sql
CREATE OR REPLACE FUNCTION public._session_user(p_token text, p_role text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_session_id uuid;
  v_user_id text;
  v_last_used timestamptz;
begin
  if coalesce(p_token, '') = '' or p_role is null then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  select s.id, s.user_id, s.last_used_at
    into v_session_id, v_user_id, v_last_used
  from sessions s
  where s.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
    and s.role = p_role
    and s.revoked = false
    and s.expires_at > now();

  if not found then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  if p_role = 'eleve' and not exists (
    select 1 from eleves e where e.id = v_user_id and coalesce(e.banni, false) = false
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  elsif p_role = 'inspecteur' and not exists (
    select 1 from inspecteurs i where i.id = v_user_id and coalesce(i.banni, false) = false
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  elsif p_role = 'etablissement' and not exists (
    select 1 from etablissements et where et.id = v_user_id
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  elsif p_role = 'admin' and not exists (
    select 1 from admins a where a.id = v_user_id and a.actif = true
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  if v_last_used < now() - interval '10 minutes' then
    update sessions s set last_used_at = now() where s.id = v_session_id;
  end if;

  return v_user_id;
end; $function$;
```

**APRÈS** (identique à `…-e.sql`, section 2)
```sql
CREATE OR REPLACE FUNCTION public._session_user(p_token text, p_role text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_session_id uuid;
  v_user_id text;
  v_last_used timestamptz;
begin
  -- Rôles admis uniquement (le compte élève a été supprimé) : tout autre rôle est
  -- refusé d'emblée, même si une ligne sessions subsistait.
  if coalesce(p_token, '') = '' or p_role is null
     or p_role not in ('inspecteur', 'etablissement', 'admin') then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  select s.id, s.user_id, s.last_used_at
    into v_session_id, v_user_id, v_last_used
  from sessions s
  where s.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
    and s.role = p_role
    and s.revoked = false
    and s.expires_at > now();

  if not found then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  if p_role = 'inspecteur' and not exists (
    select 1 from inspecteurs i where i.id = v_user_id and coalesce(i.banni, false) = false
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  elsif p_role = 'etablissement' and not exists (
    select 1 from etablissements et where et.id = v_user_id
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  elsif p_role = 'admin' and not exists (
    select 1 from admins a where a.id = v_user_id and a.actif = true
  ) then
    raise exception 'SESSION_INVALIDE' using errcode = 'P0401';
  end if;

  if v_last_used < now() - interval '10 minutes' then
    update sessions s set last_used_at = now() where s.id = v_session_id;
  end if;

  return v_user_id;
end; $function$;
```
**Différence** : la branche `eleve` est retirée, et une liste blanche des rôles est ajoutée dans la première condition. Sans elle, un rôle sans branche (`eleve`) aurait été **accepté** si une ligne `sessions` avait survécu.

### A.2 `password_reset_create(p_role text, p_email text, p_token_hash text)` — `supabase-migration-2026-09-27-reset-4a.sql`, lignes 99-170

**AVANT** : les lignes concernées, le reste étant identique à APRÈS.
```sql
  if p_role is null or p_role not in ('eleve', 'inspecteur', 'etablissement') then
    return null;
  end if;
  ...
  if p_role = 'eleve' then
    select e.id, trim(e.email) into v_account_id, v_email
    from eleves e
    where nullif(trim(e.email), '') is not null
      and lower(trim(e.email)) = lower(trim(p_email))
      and coalesce(e.banni, false) = false;
  elsif p_role = 'inspecteur' then
    select i.id, trim(i.email) into v_account_id, v_email
    from inspecteurs i
    where nullif(trim(i.email), '') is not null
      and lower(trim(i.email)) = lower(trim(p_email))
      and coalesce(i.banni, false) = false;
  else
    ...
```
Le corps AVANT complet se trouve dans le dépôt, `supabase-migration-2026-09-27-reset-4a.sql` lignes 99-173 (fonction et droits) : c'est lui qu'il faut recoller en cas de retour arrière.

**APRÈS** : le corps complet est dans `…-e.sql`, section 3. **Différences** : la liste des rôles passe à `('inspecteur', 'etablissement')`, et la branche `eleve` est retirée ; `inspecteur` devient le premier `if`. Tout le reste est inchangé : limite de 3 demandes par heure, verrou, invalidation des liens précédents, droits (service_role seulement).

### A.3 `reset_password_with_token(p_token text, p_new_password text)` — `supabase-migration-2026-09-27-reset-4a.sql`, lignes 184-237

**AVANT** : les lignes concernées.
```sql
  if v_row.role = 'eleve' then
    update eleves e set password = p_new_password where e.id = v_row.account_id;
  elsif v_row.role = 'inspecteur' then
    update inspecteurs i set password = p_new_password where i.id = v_row.account_id;
  elsif v_row.role = 'etablissement' then
    update etablissements et set password = p_new_password where et.id = v_row.account_id;
  end if;
```
Le corps AVANT complet est dans le dépôt, lignes 184-237 de `reset-4a.sql`.

**APRÈS** : le corps complet est dans `…-e.sql`, section 4. **Différence** : la branche `eleve` est retirée ; `inspecteur` devient le premier `if`. Le reste est inchangé.

### A.4 `session_check(p_token text)` et `session_close(p_token text)` — **non modifiées**

- Source : `supabase-migration-2026-09-26-sessions-1-socle.sql`, lignes 129-161 et 171-187 ; jamais redéfinies depuis. Le test à blanc vérifie que la production est identique au dépôt (lignes `fonction_a_adapter`).
- **`session_check`** ne cite aucun rôle. Elle lit le rôle stocké dans `sessions`, puis délègue à `_session_user(p_token, v_role)` et renvoie `null` sur `P0401`. Une fois `_session_user` en liste blanche, un jeton `eleve` donne `null`.
- **`session_close`** révoque n'importe quel jeton, sans notion de rôle. C'est elle que le front appelle pour révoquer une ancienne session élève.
- Leur corps APRÈS est donc identique au corps AVANT.

## Annexe B — Exporter une définition actuelle (si le test à blanc dit « DIFFÉRENTE »)

Requête en lecture seule. Remplacer la signature, puis m'envoyer le résultat **sans le modifier** :
```sql
select pg_get_functiondef('public._session_user(text,text)'::regprocedure);
```
Signatures possibles :
- `public.password_reset_create(text,text,text)`
- `public.reset_password_with_token(text,text)`
- `public.session_check(text)`
- `public.session_close(text)`
