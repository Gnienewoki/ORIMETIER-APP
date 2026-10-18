# tel / email des inspecteurs hors de la clé publique : notes v2 (2026-10-18)

Ces notes remplacent `contacts-inspecteurs-notes.md`. Rien n'a été exécuté, commité ni poussé ; le dépôt n'a pas été modifié.
**État de la production** : A exécuté (contrôle 14/14) ; A2 pas encore lancé ; front pas encore déployé ; B pas lancé.

## Fichiers à déployer ou lancer (racine de Téléchargements)
| Fichier | Destination / rôle |
|---|---|
| `supabase-migration-2026-10-18-contacts-inspecteurs-A2.sql` | **nouveau** : `inspecteur_get_own_v2` renvoie aussi `message_accueil` (DROP + CREATE, bloc DO atomique) |
| `supabase-migration-2026-10-18-contacts-inspecteurs-controle-v2.sql` | **remplace** `…-controle.sql` : requête 1 = A + A2 (16 lignes), requête 2 = B (9 lignes, inchangée) |
| `supabase-migration-2026-10-18-contacts-inspecteurs-B.sql` | inchangé, après le déploiement du front |
| `admin-contacts-v3.js` → `admin.js` | **remplace** la v2 : la sauvegarde JSON intègre les contacts |
| `inspecteur-contacts-v3.js` → `inspecteur.js` | **remplace** la v2 : message d'accueil lu par `inspecteur_get_own_v2` |
| `supabase-client-contacts-v3.js` → `supabase-client.js` | **remplace** la v2 : `espInspecteurGetOwnRPC` renvoie aussi `messageAccueil` |
| `auth-contacts-v2.js` → `auth.js` | **inchangé** depuis la v2 : aucun besoin nouveau |
| `sw-contacts-v2.js` → `sw.js` | **inchangé** depuis la v2 : `orimetier-shell-v36` (aucun front v36 n'a encore été servi) |

Les fichiers `-contacts-v2.js` d'admin, d'inspecteur et de supabase-client sont remplacés par leurs `-v3` : ne pas les déployer.
Les copies v3 sont en CRLF, passent `node --check`, et leur diff avec la v2 ne contient que les changements ci-dessous. `auth-contacts-v2.js` est déjà compatible : après un changement d'e-mail, il vide le cache des coordonnées, puis e-mail et message d'accueil sont relus ensemble.

## 1. Changements de cette version
- **Sauvegarde JSON** (`espExportBackup`, devenue `async`) :
  - Elle réutilise `_espAdminInspContacts` s'il est chargé. Sinon elle appelle `admin_list_inspecteurs_contacts_v2` et garde le résultat dans ce même cache admin, qui reste en mémoire seulement.
  - Elle fusionne tel et email dans une **copie** des inspecteurs, utilisée uniquement pour le fichier exporté. `espDB()` et `sessionStorage` ne sont jamais modifiés.
  - Si la RPC échoue, l'export part quand même, sans les contacts. Ensuite une alerte : « Sauvegarde exportée SANS le téléphone ni l'e-mail des inspecteurs (contacts indisponibles : …). Réessaie plus tard pour une sauvegarde complète. »
  - Seule exception : une session admin expirée. Rien n'est exporté et le bandeau « session expirée » habituel s'affiche.
  - L'analyse des lignes RPC est partagée avec l'onglet (`espAdminInspContactsDepuisLignes`).
- **Message d'accueil** (bug ancien : vide après chaque rechargement) :
  - **Valeur affichée** : celle d'`espDB()` si elle est renseignée (enregistrée dans cet onglet), sinon celle d'`inspecteur_get_own_v2`. Pendant le chargement : « Chargement… ». Sans message : « Aucun message d'accueil défini. ».
  - **Chargement** : comme pour l'e-mail, une fois par session. Seules les lignes du profil sont redessinées (`espInspecteurRefreshOwnLignes`, qui remplace `espInspecteurRefreshEmailStatut`).
  - **Textarea** : pré-rempli avec le message ; après chargement, seulement s'il est vide et pas en cours d'édition.
  - **Après « Enregistrer le message »** : `espDB()` comme avant, plus le cache de `inspecteur_get_own_v2`, sinon un message vidé reviendrait. La ligne affichée est mise à jour tout de suite.

## 2. Ordre d'exécution (à partir de maintenant)
1. **A2** : la requête finale affiche la ligne `TABLE(id text, tel text, email text, message_accueil text)`, puis 5 × true.
2. **`…-controle-v2.sql`, requête 1** : 16 lignes à true. La ligne 4 attend 3 colonnes pour la fonction admin et 4 pour `inspecteur_get_own_v2` ; la nouvelle ligne 8 vérifie qu'aucun objet n'en dépend.
3. **Déploiement du front** : `admin-contacts-v3.js`, `inspecteur-contacts-v3.js`, `supabase-client-contacts-v3.js`, `auth-contacts-v2.js`, `sw-contacts-v2.js`. Commit et push quand vous le décidez, puis rechargement (sw v36) et tests 1 à 4.
4. **B**, puis **`…-controle-v2.sql`, requête 2** : 9 lignes à true.
5. **Tests 5 et 6.**

## 3. Tests (compte fictif : « Testeur Fictif », numéros 01000000xx, e-mails en `@example.invalid`)
1. **Admin, onglet « Comptes inspecteurs »** : « Chargement… », puis le tel et l'e-mail. Cliquer de nouveau sur l'onglet relance le chargement.
2. **Sauvegarde, cas normal** : « Exporter une sauvegarde » depuis la vue d'ensemble, sans avoir ouvert l'onglet Inspecteurs. Le fichier JSON contient `tel` et `email` pour les inspecteurs. Vérifier ensuite dans Application › Session Storage › `esp_data_cache_v1` que rien n'a été ajouté.
3. **Sauvegarde, échec de la RPC** : dans les outils du navigateur, onglet Réseau, bloquer l'URL contenant `admin_list_inspecteurs_contacts_v2`. Recharger, se reconnecter en admin, puis exporter. Attendu : le fichier est téléchargé quand même, puis l'alerte « Sauvegarde exportée SANS… » s'affiche. Débloquer ensuite.
4. **Message d'accueil** : avec le compte de test (inscription au `01 00 00 00 05` si besoin), enregistrer le message « Message de test fictif. ».
   - Recharger la page (F5) : le profil affiche « Message de test fictif. » (avant : « Aucun message d'accueil défini. ») et le textarea est pré-rempli.
   - Vider le message, enregistrer, recharger : « Aucun message d'accueil défini. ».
   - Modifier l'e-mail de récupération : le message d'accueil reste correct.
5. **Après B, console du navigateur, sans être connecté** : `(await supabaseClient.rpc('list_inspecteurs')).data.filter(r => r.tel || r.email).length` donne `0`. Un appel à `inspecteur_get_own_v2` ou `admin_list_inspecteurs_contacts_v2` avec `{ p_token: 'jeton-invente' }` donne SESSION_INVALIDE (P0401).
6. **Après B** : refaire les tests 1, 2 et 4, et la connexion par téléphone du compte de test. Rien ne doit changer.
7. **Nettoyage** (à lancer vous-même) : `select id, nom, tel from public.inspecteurs where tel like '01000000%';`, puis le `delete` correspondant.

## 4. Retour arrière
- **B** : bloc commenté à la fin de `…-B.sql` (remet le corps de production de `list_inspecteurs`, droits conservés).
- **A2** : bloc commenté à la fin de `…-A2.sql`. Il refait `DROP` + `CREATE` à l'identique de A (3 colonnes, mêmes droits). Le front v3 reste compatible : `message_accueil` absent devient `''`, et l'on revient simplement au bug d'origine (message vide après rechargement).
- **Front** : garder le front v3 est possible avec ou sans B, avec ou sans A2. Pour revenir à l'ancien : remettre les 5 fichiers du commit 8d7eef6 avec `CACHE_NAME` passé à `v37` (jamais un numéro déjà servi), et seulement après le retour arrière de B.
- **A** (après tout le reste) : `DROP FUNCTION IF EXISTS public.admin_list_inspecteurs_contacts_v2(text); DROP FUNCTION IF EXISTS public.inspecteur_get_own_v2(text);`. Ces deux lignes suppriment aussi la version A2.

## 5. Rappels des notes v1 (toujours valables)
- Vérifications (a), (b), (c) : l'e-mail du profil passe par `inspecteur_get_own_v2`. Messagerie, chat, annuaire, LYCAM, MBTI et suivi ne lisent ni tel ni e-mail. La connexion par téléphone (`inspecteur_session_open`) ne change pas. La sauvegarde JSON est désormais traitée (section 1).
- Le contrôle de doublon du téléphone à l'inscription est fait uniquement par `inspecteur_register`.

## 6. Non vérifié
- Je n'ai pas testé les écrans dans un navigateur. Les copies sont vérifiées par `node --check` et par le diff avec la v2.
- Le corps de `_session_user` en production (refus d'un inspecteur banni) : je me fie aux fichiers du dépôt.
- L'Edge Function `request-password-reset` n'est pas dans le dépôt : à confirmer par un test « Mot de passe oublié » après B.
- `message_accueil` est-il destiné à être vu par les **autres** inspecteurs ? Aujourd'hui, aucun écran ne l'affiche à un autre que son auteur (seul le profil le montre, à son propriétaire). Si c'est voulu, il faudra plus tard l'ajouter à `list_inspecteurs`. Je n'y ai pas touché.

## 7. Signalé, non corrigé
- Si `admin_list_inspecteurs_contacts_v2` échoue plusieurs fois de suite, l'alerte de l'onglet admin réapparaît à chaque redessin, comme pour les établissements. J'ai gardé ce comportement.
