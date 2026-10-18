# Longueur minimale des mots de passe (phase 8) : notes (2026-10-18)

**Règle** : tout **nouveau** mot de passe fait au moins 8 caractères. La **connexion** n'est jamais touchée : un ancien mot de passe plus court reste accepté.
Rien n'a été exécuté, commité ni poussé ; le dépôt n'a pas été modifié (état de départ : commit `ea295d3`, sw v36).

## 1. Inventaire (lecture seule, dépôt à `ea295d3`)

| Où un mot de passe est créé / changé | Front : contrôle actuel | Base : contrôle actuel |
|---|---|---|
| Inscription inspecteur | `inspecteur.js:26` (champ), `inspecteur.js:51-54` : obligatoire seulement, **aucun minimum** | `inspecteur_register` (`supabase-migration-2026-10-18-inscription-inspecteur-A.sql:73-96`) : obligatoire, 128 au plus, hash bcrypt refusé ; **aucun minimum** |
| Changement de mot de passe par l'inspecteur | **n'existe pas** (aucun écran) | **n'existe pas** (aucune fonction) |
| Mot de passe oublié : demande | `auth.js:913-948` : e-mail seulement, aucun mot de passe | Edge Function `supabase/functions/request-password-reset/index.ts` et `password_reset_create` : jeton et e-mail seulement → **rien à changer** |
| Mot de passe oublié : écran `#reset=` | `auth.js:960` (champ), `auth.js:987` : `pass1.length < 4` ; `auth.js:1001` : message « 4 caractères minimum » | `reset_password_with_token` (`supabase-migration-2026-10-17-suppression-eleve-e.sql:242`, ou `supabase-migration-2026-09-27-reset-4a.sql:197` si l'étape e n'est pas lancée) : `length < 4` → `MOT_DE_PASSE_INVALIDE` |
| Établissement : demande d'inscription | `etablissement.js:74` (champ), `etablissement.js:449-456` : obligatoire + confirmation, **aucun minimum** | `etablissement_register` (`supabase/historique/etab-3-demandes-tout-en-un.sql:317`) : `length(trim()) = 0` → `false` ; **aucun minimum** |
| Établissement : validation de la demande par l'admin | — | `admin_valider_demande_v2` recopie le **hash** de la demande : pas de nouveau mot de passe, rien à changer |
| Établissement : récupération de fiche (code) | `etablissement.js:564` (libellé « 4 caractères minimum »), `etablissement.js:664` : `pass.length < 4` | `etablissement_claim_v2` (`supabase/historique/codes-2-migration.sql:178-181`) : obligatoire seulement |
| Établissement : changement de mot de passe | **n'existe pas** | **n'existe pas** |
| Élèves | compte supprimé du front (`b969c96`) | plus aucune fonction d'écriture (étape e). Si e n'est pas lancée, la branche `eleve` de `reset_password_with_token` reçoit le même contrôle : c'est la même ligne |
| Admin : création d'un compte | `admin.js:1044` (libellé « 8 caractères minimum »), `admin.js:1055-1065` : confirmation seulement | `admin_create_admin_v2` (`supabase/historique/5a-4-admin-principal.sql:210-212`) : `< 8` → `MOT_DE_PASSE_TROP_COURT` **déjà en place** |
| Admin : changer son mot de passe (`admin_change_password_v2`) | **aucun écran** (`admin.js:950-951` : « viendront avec 5b-4 ») | `supabase-migration-2026-09-29-admins-5a-3-comptes.sql:257-259` : `< 8` → `MOT_DE_PASSE_TROP_COURT` **déjà en place** |
| Ancien mot de passe admin unique (`admin_config`) | — | aucune fonction de changement (SQL Editor seulement) |
| **Connexion** (inchangée) | `inspecteur.js:87-104`, `etablissement.js:499-512`, `admin.js:14-35` : aucune longueur | `*_session_open` : aucune longueur. Vérifié par le fichier 0 (ligne 5) et le contrôle (ligne 15, tests T8 et T9) |

## 2. Fichiers produits (racine de Téléchargements)

| Fichier | Destination / rôle |
|---|---|
| `supabase-migration-2026-10-18-mdp-longueur-0-test-a-blanc.sql` | une requête en lecture seule, avant A (LF) |
| `supabase-migration-2026-10-18-mdp-longueur-A.sql` | bloc DO atomique avec gardes, vérification finale, retour arrière commenté (LF) |
| `supabase-migration-2026-10-18-mdp-longueur-controle.sql` | requête 1 en lecture seule (16 lignes) ; requête 2 : 9 tests réels, toujours annulés (LF) |
| `auth-mdp-v37.js` → `auth.js` | outils communs (seuil, message, indicateur) ; écran de réinitialisation |
| `inspecteur-mdp-v37.js` → `inspecteur.js` | inscription inspecteur |
| `etablissement-mdp-v37.js` → `etablissement.js` | demande d'inscription et récupération de fiche |
| `admin-mdp-v37.js` → `admin.js` | création d'un compte admin |
| `supabase-client-mdp-v37.js` → `supabase-client.js` | message de `MOT_DE_PASSE_TROP_COURT` pour `inspecteur_register` |
| `sw-mdp-v37.js` → `sw.js` | `CACHE_NAME = 'orimetier-shell-v37'` |
| `mdp-longueur-notes.md` | ces notes (LF) |

Les copies JS sont en CRLF et passent `node --check`. Leur diff avec le dépôt ne contient que les lignes décrites en section 3. Dans le dossier de travail, `etablissement.js` est en LF et les autres en CRLF ; avec `core.autocrlf=true`, Git stocke de toute façon tout en LF.

## 3. Ce qui change

### Base (fichier A)
- **Méthode** : aucun corps de fonction n'est recopié. A lit la définition **en production**, vérifie qu'un passage repère y figure exactement une fois (sinon GARDE, et rien n'est modifié), insère le contrôle, puis réinstalle la fonction. `CREATE OR REPLACE` conserve le propriétaire, les droits, SECURITY DEFINER et le search_path, et le bloc les revérifie. Je l'ai simulé sur les corps versionnés dans le dépôt, en LF et en CRLF : chaque repère est trouvé une fois, et le retour arrière rend un texte identique à l'original.
- **`inspecteur_register`** : `{ok:false, erreur:'MOT_DE_PASSE_TROP_COURT'}`, juste après `CHAMPS_OBLIGATOIRES`.
- **`etablissement_claim_v2`** : même retour, placé **avant** la lecture de la fiche et du code. Un mot de passe trop court ne compte donc pas comme un essai raté, et le code n'est pas consommé.
- **`etablissement_register`** : `raise exception 'MOT_DE_PASSE_TROP_COURT'`. C'est le même mécanisme que `DOUBLON`, puisque la fonction ne renvoie qu'un booléen. Le contrôle est placé avant les contrôles de doublon.
- **`reset_password_with_token`** : le seuil passe de 4 à 8 et lève `MOT_DE_PASSE_TROP_COURT`. `MOT_DE_PASSE_INVALIDE` reste pour un texte en forme de hash bcrypt. Le contrôle a toujours lieu avant la lecture du jeton : un refus ne consomme pas le lien.
- **Comptes admin** : non modifiés (déjà à 8). Ils sont revérifiés.

### Front (v37)
- **Outils communs** (`auth.js`) :
  - `ESP_MDP_MIN = 8` et `ESP_MDP_TROP_COURT_MSG` = « Le mot de passe doit contenir au moins 8 caractères. » ;
  - `espMdpTropCourt(valeur)` compte les caractères comme `length()` en base : un émoji vaut 1, et non 2 comme avec `.length` ;
  - `espMdpIndicateurHtml(id)` et `espMdpIndicateurMaj(input)` affichent l'indicateur.
- **Indicateur discret** : une ligne grise (`esp-sub`, 12 px) sous le champ « mot de passe » (pas sous la confirmation), reliée par `aria-describedby`. Elle affiche :
  - « 8 caractères minimum » quand le champ est vide ;
  - puis « 5 / 8 caractères minimum » pendant la saisie ;
  - puis « 9 caractères : longueur suffisante ».
  - Elle est purement indicative : rien ne bloque pendant la saisie.
- **Contrôle à l'envoi** (avant tout appel réseau), avec le même message :
  - inscription inspecteur ;
  - demande d'inscription établissement ;
  - récupération de fiche ;
  - réinitialisation ;
  - création d'un compte admin.
- **Erreur du serveur** `MOT_DE_PASSE_TROP_COURT`, au cas où le front serait contourné : même message dans les 5 écrans.
  - inspecteur : table `ESP_INSP_REGISTER_ERREURS` ;
  - établissement : message de l'exception ;
  - récupération : `case` de `espEtabClaim` ;
  - réinitialisation : `catch` ;
  - admin : `ESP_ADMIN_COMPTE_ERREURS`, dont le texte devient la phrase complète.
- **Libellés** : « (4 caractères minimum) » disparaît de la récupération de fiche, et « (8 caractères minimum) » de la création admin. L'indicateur les remplace. L'écran de réinitialisation ne dit plus « 4 caractères minimum ».
- **Connexion** : aucun des 3 écrans de connexion n'est modifié.

## 4. Ordre d'exécution
1. **0 (test à blanc)** : m'envoyer le résultat. Points bloquants :
   - lignes `x2` = 1 (passage repère trouvé une fois) ;
   - lignes `x3` = false ;
   - lignes `x4` : propriétaire égal à l'utilisateur de la ligne 1 ;
   - ligne 6 : aucune fonction **(anon)** hors de la liste attendue.
2. **Compte de test « ancien mot de passe court »**, avec le front **actuel** (v36), qui accepte encore 4 caractères : inscrire « Testeur Fictif » au `01 00 00 00 07` avec le mot de passe `abcd`. Il servira au test 5.
3. **Front v37** : déployer les 6 fichiers, puis commit et push quand tu le décides. Recharger (sw v37). Le front passe en premier : il bloque lui-même moins de 8 caractères, et il est compatible avec la base avant et après A.
4. **A** : la requête finale affiche 6 lignes à true.
5. **Contrôle, requête 1** : 16 lignes à true. **Requête 2** : une erreur volontaire « RÉSULTAT DES TESTS : 9 / 9 OK (tout est annulé, rien n'est enregistré) | T1 ok | … ».
6. **Tests navigateur** (section 5).

## 5. Tests navigateur (données fictives)
1. **Inscription inspecteur** (`01 00 00 00 08`) :
   - Avec `abc1234` : l'indicateur affiche « 7 / 8 caractères minimum ». « Créer mon compte » répond « Le mot de passe doit contenir au moins 8 caractères. », sans appel réseau (vérifier l'onglet Réseau).
   - Avec `abcd1234` : le compte est créé, puis connecté.
2. **Demande d'inscription établissement** (« Établissement Fictif Test », `test-etab@example.invalid`) avec 7 caractères : même message. Ne pas aller au bout avec 8 caractères, sauf pour refuser ensuite la demande côté admin.
3. **Récupération de fiche** : saisir 7 caractères. Le message s'affiche **avant** l'envoi, et aucun essai n'est consommé (le compteur « il vous reste n essai(s) » ne bouge pas).
4. **Admin › Comptes admin › Créer**, avec 7 caractères : même message. Ne pas créer le compte, puisqu'il est limité à 5 actifs.
5. **Connexion du compte de l'étape 2** (`0100000007` / `abcd`) : **elle doit réussir**. C'est le point clé de la règle.
6. **Réinitialisation**, facultatif, avec une boîte e-mail de test à toi sur le compte de l'étape 2 : 7 caractères → message ; 8 caractères → mise à jour, puis connexion avec le nouveau mot de passe.
7. **Nettoyage** (à lancer toi-même) : `select id, nom, tel from public.inspecteurs where tel like '01000000%';`, puis le `delete` correspondant.

## 6. Retour arrière
- **A** : bloc commenté à la fin de `…-A.sql`. Retirer les « -- » de début de ligne, puis coller le bloc seul. Il retire les 4 contrôles et remet le seuil de 4 caractères à la réinitialisation, avec la même méthode et les mêmes vérifications.
- **Front** : le front v37 peut rester, avec ou sans A, puisqu'il garde son propre contrôle. Pour revenir au front v36 : remettre les 6 fichiers de `ea295d3` avec `CACHE_NAME` passé à `v38` (jamais un numéro déjà servi), de préférence après le retour arrière de A. Sinon, les écrans v36 affichent un message générique sur un mot de passe de 4 à 7 caractères.

## 7. Non vérifié (pas d'accès à Supabase)
- Les définitions en production des 4 fonctions : A ne suppose rien et s'arrête si un repère manque ou est en double. Le fichier 0 le montre à l'avance.
- Le propriétaire des fonctions (garde dédiée) et l'état de l'étape e : les deux versions de `reset_password_with_token` sont gérées.
- Je n'ai pas testé les écrans dans un navigateur. Les copies sont vérifiées par `node --check` et par le diff.

## 8. Signalé, non corrigé
- `etablissement_register` ne refuse pas un texte en forme de hash bcrypt, contrairement aux trois autres fonctions. Celui-ci serait stocké tel quel dans la demande, puis recopié à la validation. Sans gain de droits (l'établissement choisit son propre mot de passe), mais c'est incohérent.
- `etablissement_register` et `etablissement_claim_v2` n'ont pas de longueur **maximale**. bcrypt ne prend en compte que les 72 premiers octets.
- Aucun écran ne permet à un inspecteur, un établissement ou un admin de **changer** son mot de passe une fois connecté. Il ne reste que « Mot de passe oublié ». `admin_change_password_v2` existe côté base sans écran.
