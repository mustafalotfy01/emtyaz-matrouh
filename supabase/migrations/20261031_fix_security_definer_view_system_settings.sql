-- ==============================================================================
-- MIGRATION: Fix Security Definer View for system_settings
-- Date: 2026-10-31
-- File: 20261031_fix_security_definer_view_system_settings.sql
-- Description: Sets security_invoker = true on public.system_settings view so
--              that querying users enforce RLS policies of the underlying table.
-- ==============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_views
        WHERE schemaname = 'public'
          AND viewname = 'system_settings'
    ) THEN
        ALTER VIEW public.system_settings SET (security_invoker = true);
    END IF;
END $$;
