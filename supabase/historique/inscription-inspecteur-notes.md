# Inscription inspecteur durcie : notes (2026-10-18)

Rien n'a été exécuté, commité ni poussé. Le dépôt n'a pas été modifié. Tous les fichiers sont à la racine de Téléchargements :

| Fichier | Rôle |
|---|---|
| `supabase-migration-2026-10-18-inscription-inspecteur-0-test-a-blanc.sql` | une requête en lecture seule : état avant A |
| `supabase-migration-2026-10-18-inscription-inspecteur-A.sql` | additif : crée `inspecteur_register` |
| `supabase-migration-2026-10-18-inscription-inspecteur-B.sql` | après le déploiement du front : retire l'INSERT direct et la policy |
| `supabase-migration-2026-10-18-inscription-inspecteur-controle.sql` | contrôles après A (requête 1) et après B (requête 2) |
| `supabase-client-inscription-v2.js` | à copier sur `supabase-client.js` : seule `espInsertInspecteur` change |
| `sw-inscription-v2.js` | à copier sur `sw.js` : seul `CACHE_NAME = 'orimetier-shell-v35'` change |

`inspecteur.js` (l'écran d'inscription) **ne change pas**. Il affiche déjà `e.message` après « Erreur lors de la création du compte : », et la nouvelle fonction lève une `Error` au message en français.

## 1. Audit du front actuel (lecture seule)
1. Écran : `espRenderInspecteurAuth('register')` puis `espInspecteurRegister()` (`inspecteur.js:40-98`), avec un verrou anti double clic.
2. Validations côté client : nom, téléphone et mot de passe obligatoires. Le téléphone passe par `normalizeTel`, l'e-mail est trimé. Pas de longueur minimale ni maximale, pas de format d'e-mail.
3. Tel déjà utilisé : contrôle préalable sur une liste fraîche `list_inspecteurs` (numéros normalisés), message « Un compte existe déjà avec ce numéro de téléphone. ».
4. E-mail déjà utilisé : aucun contrôle client. L'erreur Postgres brute s'affiche (« Erreur lors de la création du compte : duplicate key value… »).
5. `active: true` est envoyé en dur. `espInspecteurToRow` n'envoie ni certifie, ni banni, ni certification_demandee, mais rien côté serveur n'empêche un autre client de les envoyer.
6. `espInsertInspecteur` (`supabase-client.js:202`) = `from('inspecteurs').insert([row])`. Elle n'est appelée que par `inspecteur.js:75`.
7. Après l'insert : ajout au cache d'onglet (sans le mot de passe), puis `inspecteur_session_open(tel, pass)`. C'est le serveur qui crée le jeton, puis `espSetTokenSession` + `platformUnlock` : l'inspecteur est connecté aussitôt.
8. Si l'ouverture de session échoue : retour à l'écran de connexion avec « Compte créé. Connecte-toi… ».
9. Le mot de passe part en clair et `trg_hash_password` le hache. Un texte qui ressemble déjà à un hash bcrypt serait stocké tel quel, d'où le refus `MOT_DE_PASSE_INVALIDE` dans la fonction.

## 2. Ordre d'exécution
1. **0** (SQL Editor) : coller le résultat dans la conversation. Points à vérifier : `pk_nom = inspecteurs_pkey`, `rls_forcee = false`, `insert_anon = true`, `actifs_faux` et `actifs_nul` cohérents.
2. **A** : la requête finale doit afficher 5 × true.
3. **Contrôle, requête 1** : 12 lignes à true.
4. **Test 1** (ci-dessous, avant B) : il prouve le trou.
5. **Déploiement du front** : `supabase-client-inscription-v2.js` → `supabase-client.js`, `sw-inscription-v2.js` → `sw.js`, puis commit et push quand vous le décidez.
6. **Test 2** : inscription par l'écran, avec le nouveau front.
7. **B**, puis **contrôle, requête 2** : 11 lignes à true.
8. **Test 3** : le trou est fermé et l'inscription par l'écran fonctionne toujours.
9. **Nettoyage** des comptes de test (section 5).

## 3. Tests (noms et numéros inventés)
Dans la console du navigateur, sur une page du site (`supabaseClient` y est global).

**Test 1, avant B : INSERT direct par la clé publique avec `certifie = true`**
```js
await supabaseClient.from('inspecteurs').insert([{ id:'test-insert-direct-1', nom:'Testeur', prenoms:'Fictif Direct',
  tel:'0100000099', email:'', password:'TestDirect-1', active:true, date_inscription:'18/10/2026', certifie:true }]);
```
Attendu avant B : `{ error: null }` (le trou est confirmé : compte certifié créé). **À nettoyer** (section 5).

**Test 1 bis, après A : tentative d'injection par la RPC**
```js
await supabaseClient.rpc('inspecteur_register', { p_id:'x', p_nom:'x', p_prenoms:'', p_fonction:'', p_cio:'',
  p_tel:'0100000098', p_email:'', p_password:'x', p_date_inscription:'18/10/2026', certifie:true });
```
Attendu : une erreur PostgREST « Could not find the function… » (PGRST202). Aucun paramètre `certifie` n'existe, rien n'est créé.

**Test 2, nouveau front déployé (rechargement forcé, sw v35 actif)**
- Inscription : nom « Testeur », prénoms « Fictif », fonction « Test », CIO « Test », téléphone `01 00 00 00 01`, e-mail `testeur.fictif@example.invalid`, un mot de passe quelconque. Attendu : connexion immédiate au tableau de bord, et aucun badge « certifié ».
- Déconnexion, puis nouvelle inscription avec le même téléphone. Attendu : « Un compte existe déjà avec ce numéro de téléphone. » (contrôle du front, avant même la RPC).
- Nouvelle inscription avec un autre téléphone (`0100000002`) et le même e-mail (casse différente acceptée). Attendu : « Erreur lors de la création du compte : Un compte existe déjà avec cette adresse e-mail. »
- Mot de passe commençant par `$2b$` (téléphone `0100000003`). Attendu : « … Ce mot de passe ne peut pas être utilisé, choisis-en un autre. »
- En SQL, vérification : `select id, certifie, banni, certification_demandee, active, password ~ '^\$2[aby]\$' as hache from public.inspecteurs where tel like '01000000%';`. Attendu pour le compte du test 2 : false, false, false, true, true.

**Test 3, après B**
- Relancer le test 1 avec `id:'test-insert-direct-2'` et `tel:'0100000097'`. Attendu : une erreur `42501` (« permission denied for table inspecteurs ») ou une violation de RLS, et aucune ligne créée.
- Refaire une inscription par l'écran (téléphone `0100000004`). Attendu : elle fonctionne toujours, avec connexion immédiate.

## 4. Retour arrière
- **B** : bloc commenté à la fin de `…-B.sql` (GRANT INSERT + recréation de la policy à l'identique). Il rouvre le trou : à n'utiliser que si l'inscription est cassée.
- **Front** : remettre `supabase-client.js` et `sw.js` d'avant (le commit actuel), avec `CACHE_NAME` passé à `v36` (jamais revenir à un numéro déjà servi), et uniquement **après** le retour arrière de B, sinon plus personne ne peut s'inscrire.
- **A** : `DROP FUNCTION IF EXISTS public.inspecteur_register(text, text, text, text, text, text, text, text, text);`, uniquement une fois le front revenu à l'INSERT direct.

## 5. Nettoyage des comptes de test (à lancer vous-même)
```sql
-- Vérifier d'abord la liste, puis supprimer (trg_inspecteurs_revoke_sessions ferme leurs sessions)
select id, nom, prenoms, tel, certifie from public.inspecteurs where tel like '01000000%' or id like 'test-insert-direct-%';
-- delete from public.inspecteurs where tel like '01000000%' or id like 'test-insert-direct-%';
```
Si une clé étrangère (messages privés, suivi, LYCAM) bloque la suppression, c'est que le compte de test a servi : supprimer d'abord ces lignes de test.

## 6. Ce que je n'ai pas pu vérifier (pas d'accès à Supabase)
- L'état réel de la production par rapport à la référence `supabase/reference/live-2026-09-26.sql` : le fichier 0 le relève.
- Le nom de la clé primaire (supposé `inspecteurs_pkey`, la fonction accepte « %pkey »), et le fait que les index uniques s'appellent bien `inspecteurs_tel_unique` et `inspecteurs_email_unique` (garde dans A).
- Le propriétaire de la table et de la fonction : si la fonction n'appartient pas au propriétaire de la table, ou si FORCE RLS est actif, l'INSERT de la fonction serait bloqué après B. B a une garde FORCE RLS, et la seconde partie du test 3 (inscription par l'écran après B) le confirme.
- Les autres policies ou droits sur inspecteurs (UPDATE, DELETE pour anon) : relevés par le fichier 0, **non traités ici**.
- La valeur réelle de `active` pour les comptes existants (le fichier 0 la compte) ; la fonction impose `true` comme le front actuel.
- Le comportement exact de PostgREST quand on lui passe un paramètre inconnu (test 1 bis) : attendu PGRST202.

## 7. Signalé, non corrigé
- Pas de longueur minimale de mot de passe à l'inscription (le front n'en impose pas, la fonction non plus). `reset_password_with_token` en exige 4.
- Pas de contrôle de format de l'e-mail (ni dans le front, ni dans la fonction).
- `list_inspecteurs` renvoie le téléphone de tous les inspecteurs à la clé publique. Le contrôle de doublon du front s'en sert. Avec la fonction, ce contrôle client devient redondant (la fonction refuse aussi les numéros normalisés identiques).
- bcrypt n'utilise que les 72 premiers octets du mot de passe (la fonction plafonne à 128 caractères).
- `messages_inspecteurs` : non touché, comme demandé.
