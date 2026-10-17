-- ============================================================
-- ORIMETIER — Visites : ajoute 'technique.html' à la liste fermée de log_visite
-- À exécuter dans le SQL Editor de Supabase, APRÈS le test à blanc
-- (visites-technique-0) et de préférence AVANT le déploiement du front.
--
-- Contexte : technique.html (ancien contenu de l'accueil) était comptée sous
-- 'index.html'. La nouvelle page d'accueil compte désormais ses visites sous
-- 'index.html', et technique.html sous sa propre clé 'technique.html'.
-- Seule la liste fermée change : corps repris de supabase/reference/live-2026-09-26.sql.
-- Aucune ligne de la table visites n'est modifiée ni supprimée. CREATE OR
-- REPLACE conserve les droits d'exécution existants (anon, authenticated).
-- ============================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.log_visite(p_page text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_page not in (
    'index.html', 'technique.html', 'general.html', 'superieur.html', 'concours.html',
    'eleves.html', 'espaces.html', 'liens-formation.html'
  ) then
    return false;
  end if;

  insert into visites(page, visited_at) values (p_page, now());
  return true;
end; $function$;

-- Vérification : doit afficher la nouvelle liste, 'technique.html' comprise.
SELECT pg_get_functiondef('public.log_visite(text)'::regprocedure) AS definition_apres;

COMMIT;
