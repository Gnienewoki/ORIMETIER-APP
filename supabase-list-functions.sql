-- À exécuter dans l'éditeur SQL de Supabase.
-- Corrige le bug "permission denied for table eleves/inspecteurs" :
-- ces tables (ainsi que etablissements) n'ont aucun droit SELECT accordé à
-- la clé publique (anon), et l'app essayait de les lire directement.
--
-- Ces 3 fonctions RENDENT la lecture possible SANS accorder de SELECT sur
-- les tables elles-mêmes : elles tournent en SECURITY DEFINER (droits du
-- propriétaire) et ne renvoient explicitement jamais la colonne "password".
-- C'est plus sûr qu'un GRANT SELECT direct, qui exposerait aussi le mot de
-- passe si une requête l'oubliait un jour dans son "select".

CREATE OR REPLACE FUNCTION public.list_eleves()
RETURNS TABLE(id text, nom text, prenoms text, classe text, etablissement text, tel text, email text, riasec jsonb, active boolean, date_inscription text, banni boolean)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select id, nom, prenoms, classe, etablissement, tel, email, riasec, active, date_inscription, banni
  from eleves;
$function$;

-- list_inspecteurs : ajout de message_accueil (message affiché sur le profil
-- de l'inspecteur, près de sa photo). DROP nécessaire : ajouter une colonne
-- au retour d'une fonction TABLE change son type, ce que CREATE OR REPLACE
-- seul refuse.
DROP FUNCTION IF EXISTS public.list_inspecteurs();
CREATE OR REPLACE FUNCTION public.list_inspecteurs()
RETURNS TABLE(id text, nom text, prenoms text, fonction text, cio text, tel text, email text, active boolean, date_inscription text, certifie boolean, banni boolean, avatar_url text, certification_demandee boolean, message_accueil text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select id, nom, prenoms, fonction, cio, tel, email, active, date_inscription, certifie, banni, avatar_url, certification_demandee, message_accueil
  from inspecteurs;
$function$;

-- list_etablissements : ajout de region et quartier (localisation utilisée
-- par la recherche d'établissements côté élève). Même raison de DROP.
DROP FUNCTION IF EXISTS public.list_etablissements();
CREATE OR REPLACE FUNCTION public.list_etablissements()
RETURNS TABLE(id text, nom text, region text, ville text, quartier text, type text, responsable text, tel text, email text, statut text, active boolean, date_inscription text, filieres_proposees jsonb)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  select id, nom, region, ville, quartier, type, responsable, tel, email, statut, active, date_inscription, filieres_proposees
  from etablissements;
$function$;
