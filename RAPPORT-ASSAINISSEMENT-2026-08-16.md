# Rapport d'assainissement — ORIMETIER-APP

**Date** : 2026-08-16
**Périmètre** : schéma `public` de la base Supabase de production, comparé au contenu versionné du repo Git.
**Nature** : diagnostic uniquement. Aucune fonction, table ou fichier n'a été modifié, supprimé ou créé pendant cette analyse. Ce document sert de base à une Phase 2 de nettoyage, qui reste à planifier et exécuter séparément.

**Méthode** : inventaire complet de `pg_proc`/`pg_namespace` sur le schéma `public` (61 lignes, 55 fonctions uniques), croisé avec :
- les 13 fichiers `.sql` versionnés dans le repo (`git ls-files` / recherche `CREATE FUNCTION`),
- les appels RPC réels émis par le frontend (`supabase-client.js`, recherche `.rpc(...)`).

PostgreSQL ne trace nativement aucune date de dernière modification de fonction (pas de colonne système `updated_at`) : cette information n'est pas récupérable en base, seul l'historique Git ou un éventuel audit externe pourrait la fournir.

---

## 1. Fonctions à overloads multiples — nettoyage à planifier (Phase 2)

Trois fonctions ont plusieurs signatures superposées en production. PostgreSQL les traite comme des fonctions indépendantes tant qu'aucun `DROP FUNCTION` explicite n'est exécuté sur les anciennes signatures — chaque `CREATE OR REPLACE FUNCTION` avec une liste de paramètres différente **ajoute** une version au lieu d'en remplacer une, sauf si les types de paramètres sont identiques.

### 1.1 `etablissement_claim_by_code` — 4 versions

| # | Signature | Statut |
|---|---|---|
| 1 | `(p_code text, p_email text, p_password text)` | ancienne, probablement obsolète |
| 2 | `(p_code text, p_email text, p_password text, p_responsable text, p_tel text, p_tel2 text, p_tel3 text)` | intermédiaire |
| 3 | `(p_code text, p_email text, p_password text, p_responsable text, p_tel text, p_tel2 text, p_tel3 text, p_site_web text)` | intermédiaire |
| 4 | `(p_code text, p_email text, p_password text, p_responsable text, p_tel text, p_tel2 text, p_tel3 text, p_site_web text, p_contact_tel text)` | **la plus complète — probablement la seule appelée par le frontend** |

Le frontend (`supabase-client.js:186`) appelle `etablissement_claim_by_code` par paramètres nommés (PostgREST), donc seule la version dont la signature couvre tous les paramètres nommés utilisés peut réellement être invoquée sans ambiguïté. **Candidates au `DROP FUNCTION`** : versions 1 à 3, après confirmation qu'aucun appelant externe (script, intégration tierce) ne dépend d'une signature plus courte.

### 1.2 `etablissement_register` — 3 versions

Version confirmée en usage en production : celle à **20 paramètres**, incluant `p_tel2`, `p_tel3`, `p_site_web`, `p_contact_tel` (confirmé le 2026-08-16 via `pg_get_functiondef`). Les deux autres versions (moins de paramètres, sans `p_contact_tel` et/ou sans `p_tel2`/`p_tel3`/`p_site_web`) sont des reliquats d'évolutions successives visibles dans l'historique du repo (`supabase-migration.sql` → `...-etab-register-tel2-siteweb.sql` → `...-etab-register-bloque-doublon.sql` → `...-demandes-inscription-2...sql`).

⚠️ Les signatures exactes des versions 1 et 2 (types et ordre précis des paramètres) n'ont pas été extraites individuellement dans cette phase de diagnostic — **avant tout `DROP FUNCTION` en Phase 2, il faut relire le `arguments`/`full_signature` exact de chacune des 3 lignes correspondantes dans le résultat brut de l'inventaire `pg_proc`**, pour cibler précisément les deux anciennes versions sans erreur de signature.

### 1.3 `etablissement_update_info` — 2 versions

| # | Signature | Statut |
|---|---|---|
| 1 | `(p_etab_id text, p_password text, p_nom text, p_type text, p_responsable text, p_tel text, p_email text)` | ancienne, sans `contact_tel` |
| 2 | `(p_etab_id text, p_password text, p_nom text, p_type text, p_responsable text, p_tel text, p_email text, p_contact_tel text DEFAULT NULL)` | **version courante, définie dans `supabase-migration-2026-08-15-etab-dashboard-contact-fields.sql:19`** |

Ce doublon n'était pas documenté avant cette analyse. La version 2 est celle versionnée dans le repo et correspond à l'appel frontend (`supabase-client.js:395`). Version 1 : **candidate au `DROP FUNCTION`**.

---

## 2. Pattern "column reference ambiguous" — état des lieux

Bug structurel : une fonction `LANGUAGE plpgsql` avec `RETURNS TABLE(id ...)` déclare `id` comme paramètre de sortie (variable plpgsql). Toute référence non qualifiée à `id` dans le corps de la fonction (typiquement dans une clause d'authentification `where id = ...`) devient ambiguë entre cette variable et la colonne `id` d'une table interrogée — `ERROR: column reference "id" is ambiguous`.

Analyse exhaustive menée sur les 55 fonctions : toutes celles avec une colonne `id` en sortie ont été vérifiées via leur `full_definition` (`pg_get_functiondef`) réelle en production.

### 2.1 Bug confirmé et non corrigé — `admin_list_unclaimed_codes`

```sql
if not exists (select 1 from admin_config where id = 1 and admin_password = p_admin_password) then
```

`id` et `admin_password` non qualifiés, alors que la fonction a un paramètre de sortie `id`. Bug historique déjà documenté, jamais corrigé, et **cette fonction n'existe même dans aucun fichier `.sql` versionné** (cf. section 3) — seule trace : l'appel `supabase-client.js:492` et des mentions en commentaire dans d'autres migrations.

**Fix nécessaire** (à appliquer en Phase 2, pas maintenant) :
```sql
if not exists (select 1 from admin_config where admin_config.id = 1 and admin_config.admin_password = p_admin_password) then
```
— identique au correctif déjà appliqué (en local, non commité à ce jour) sur `admin_list_demandes_inscription_etablissements` dans `supabase-migration-2026-08-16-demandes-inscription-3-admin-rpcs.sql`.

### 2.2 Fonctions vérifiées et saines (pas de fix nécessaire)

`admin_list_demandes_inscription_etablissements`, `admin_list_etablissements_full`, `etablissement_get_own`, `eleve_login`, `etablissement_login`, `inspecteur_login`, `list_eleves`, `list_etablissements`, `list_inspecteurs` : toutes déjà qualifiées correctement (`e.`, `d.`, `ac.`, `et.`) dans leur code réellement en production, ou en `LANGUAGE sql` simple (non concerné par ce pattern, propre à PL/pgSQL). **À ne pas retoucher.**

---

## 3. Drift repo/production — `supabase-migration-2026-08-15-admin-only-contact.sql`

Constat distinct du bug lui-même : le fichier versionné dans le repo contient, pour deux fonctions, un corps **non qualifié** — donc porteur du même pattern que la section 2 s'il était exécuté tel quel :

- ligne 69, `admin_list_etablissements_full` : `where id = 1 and admin_password = p_admin_password`
- ligne 105, `etablissement_get_own` : `where id = p_etab_id and password = p_password`

Or l'inventaire de production confirme que ces deux fonctions sont **déjà qualifiées correctement en base** (`ac.id`, `e.id`, etc. — pas de bug actif). Le code réellement déployé diffère donc du fichier `.sql` versionné, sans qu'aucun commit ne documente cette correction.

**Ce fichier ne doit pas être ré-exécuté tel quel** : le faire régresserait ces deux fonctions vers une version buguée. **Aucune action corrective sur la base n'est nécessaire ici** — la prod est déjà saine. L'action requise est côté repo : mettre à jour `supabase-migration-2026-08-15-admin-only-contact.sql` (ou documenter séparément) pour refléter le corps réellement en production, afin que ce fichier redevienne une source fiable.

Ce cas indique qu'au moins une correction a été appliquée en base directement, en dehors du flux "fichier de migration → commit → exécution" suivi par le reste du repo. Vaut la peine d'être gardé à l'esprit pour la suite : le repo n'est pas garanti à 100% être le miroir de ce qui a réellement été exécuté, même pour les fichiers présents.

---

## 4. `etablissement_propose_filiere` — orpheline probable, à clarifier

Cette fonction existe en production mais :
- n'a **aucune** trace dans les fichiers `.sql` du repo,
- n'est **jamais appelée** par le frontend (`supabase-client.js` appelle `etablissement_add_filiere` et `etablissement_delete_filiere`, mais jamais `etablissement_propose_filiere` — recherche insensible à la casse sur tout le repo, zéro résultat).

Contrairement aux 32 fonctions de la section 5 (absentes du repo mais actives via le frontend), celle-ci n'a **aucun appelant identifiable dans ce repo**. Hypothèses à trancher avec le porteur du projet :
- fonction legacy jamais nettoyée après un renommage (ex. remplacée par `etablissement_add_filiere`) ;
- appelée par un outil externe au repo (script admin ponctuel, intégration tierce, Zapier) ;
- réellement morte — candidate à un `DROP FUNCTION` en Phase 2 après confirmation.

**Ne rien supprimer sans confirmation explicite.**

---

## 5. Dette de versioning — fonctions en production absentes du repo

32 des 55 fonctions du schéma `public` (58%) n'ont **aucune trace** dans un fichier `.sql` versionné. La plupart sont activement appelées par le frontend (donc en usage réel, juste jamais capturées dans un fichier de migration commité) :

```
admin_delete_etablissement
admin_delete_message
admin_list_unclaimed_codes        ← cf. section 2.1, bug confirmé
admin_login
admin_restore_backup
admin_set_etab_premium
admin_set_etab_statut
admin_set_filiere_statut
admin_set_inspecteur_banni
admin_update_etab_classification
admin_valider_premium
eleve_save_riasec
eleve_update_email
etablissement_add_filiere
etablissement_delete_filiere
etablissement_demander_premium
etablissement_login
etablissement_propose_filiere     ← cf. section 4, orpheline probable
etablissement_update_photos
inspecteur_add_note
inspecteur_list_private_messages
inspecteur_login
inspecteur_lycam_create_session
inspecteur_lycam_delete_session
inspecteur_lycam_list_results
inspecteur_lycam_list_sessions
inspecteur_lycam_save_result
inspecteur_mark_private_read
inspecteur_post_private_message
inspecteur_update_email
request_password_reset
reset_password_with_token
```

Notamment concerné : **tout le système d'authentification** (`admin_login`, `etablissement_login`, `inspecteur_login`, `request_password_reset`, `reset_password_with_token`), **tout le module Premium** (`admin_set_etab_premium`, `admin_valider_premium`, `etablissement_demander_premium`), **tout le module LYCAM** (5 fonctions), et **la messagerie privée** (`inspecteur_list_private_messages`, `inspecteur_post_private_message`, `inspecteur_mark_private_read`). Aucun de ces domaines fonctionnels n'a de source SQL récupérable dans le repo à ce jour — en cas de besoin de rollback, de relecture de sécurité ou de reproduction d'environnement, le code de ces fonctions n'existe qu'en base de production.

Les 23 fonctions restantes (versionnées, avec au moins un `CREATE FUNCTION` dans le repo) ne sont pas listées ici en détail — voir l'historique de la conversation de diagnostic pour le tableau complet fonction → fichier source.

---

## 6. Autres incohérences relevées en cours d'analyse

- **Changements locaux non commités** : au moment de ce diagnostic, `supabase-migration-2026-08-15-etab-claim-tel.sql`, `supabase-migration-2026-08-15-etab-register-tel2-siteweb.sql` et `supabase-migration-2026-08-16-demandes-inscription-3-admin-rpcs.sql` ont des modifications en working tree non commitées — dont le fix du bug "id ambiguous" sur `admin_list_demandes_inscription_etablissements` (section 2). À committer et à confirmer comme appliqué (ou non) en production avant la Phase 2, pour ne pas perdre la trace de ce correctif.
- **Doublons de définition dans `supabase-migration.sql`** : `inspecteur_post_message` et `admin_post_message` y sont chacune définies deux fois (lignes 119/183 et 143/203) avec une signature identique — sans impact fonctionnel (la deuxième `CREATE OR REPLACE` écrase silencieusement la première), mais c'est un signe d'hygiène de fichier à surveiller pour la Phase 2 (fichier probablement fusionné maladroitement).
- **Colonne `contact_email` probablement morte** : le commentaire de `supabase-migration-2026-08-15-admin-only-contact.sql` (lignes 7-8) indique explicitement que cette colonne de `etablissements` n'est exposée par aucune fonction, publique ou admin. À confirmer et, si avéré inutile, candidate à suppression en Phase 2 — mais aucune action ici, diagnostic uniquement.

---

## Prochaines étapes (hors périmètre de ce rapport)

Ce document est une photographie à figer avant toute Phase 2. Avant d'exécuter le moindre `DROP FUNCTION` ou correctif SQL :
1. Committer (ou explicitement abandonner) les changements en working tree listés en section 6.
2. Extraire les signatures exactes des 2 anciennes versions de `etablissement_register` (section 1.2) depuis le résultat brut de l'inventaire, avant de cibler un `DROP FUNCTION`.
3. Confirmer avec le porteur du projet le statut de `etablissement_propose_filiere` (section 4) et de la colonne `contact_email` (section 6) avant toute suppression.
4. Planifier une politique de versioning systématique (ex. dump automatisé `pg_get_functiondef` de tout `public` dans le repo à intervalle régulier) pour empêcher la dette de la section 5 de continuer à grossir.
