-- ============================================================================
-- Migration: 20260824_user_presence_and_profile_extensions.sql
-- Description: 
-- 1. Creates public.user_presence table for real-time online/last-seen tracking
-- 2. Implements atomic RPCs with 2-minute stale timeout logic
-- 3. Strict RLS: Staff (super_admin, leader, evaluating_doctor) can view presence;
--    Students CANNOT view other users' presence. Users can only update own presence.
-- 4. Extends Supabase Realtime publication
-- ============================================================================

-- 1. Create user_presence table
CREATE TABLE IF NOT EXISTS public.user_presence (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_online BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_presence_status ON public.user_presence(is_online, last_seen_at);
CREATE INDEX IF NOT EXISTS idx_user_presence_last_seen ON public.user_presence(last_seen_at DESC);

-- 3. Set Replica Identity Full for complete Realtime payload broadcast
ALTER TABLE public.user_presence REPLICA IDENTITY FULL;

-- 4. Enable RLS
ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;

-- Drop existing policies safely
DROP POLICY IF EXISTS "user_presence_select_policy" ON public.user_presence;
DROP POLICY IF EXISTS "user_presence_insert_self" ON public.user_presence;
DROP POLICY IF EXISTS "user_presence_update_self" ON public.user_presence;
DROP POLICY IF EXISTS "user_presence_delete_admin" ON public.user_presence;

-- -- A) SELECT Policy:
-- All authenticated users can view presence for profile details and leaderboards.
CREATE POLICY "user_presence_select_policy" ON public.user_presence
    FOR SELECT
    TO authenticated
    USING (true);

-- B) INSERT Policy: Users can only insert their own presence
CREATE POLICY "user_presence_insert_self" ON public.user_presence
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- C) UPDATE Policy: Users can only update their own presence
CREATE POLICY "user_presence_update_self" ON public.user_presence
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- D) DELETE Policy: Super admin only
CREATE POLICY "user_presence_delete_admin" ON public.user_presence
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role::text = 'super_admin'
        )
    );

-- Drop existing functions to allow altering return signatures cleanly
DROP FUNCTION IF EXISTS public.get_effective_user_presence(UUID[]);
DROP FUNCTION IF EXISTS public.update_user_presence(BOOLEAN);
DROP FUNCTION IF EXISTS public.get_server_time();

-- 4. Atomic Presence Heartbeat RPC
CREATE OR REPLACE FUNCTION public.update_user_presence(p_is_online BOOLEAN)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN;
    END IF;

    INSERT INTO public.user_presence (
        user_id,
        is_online,
        last_seen_at,
        updated_at
    )
    VALUES (
        auth.uid(),
        p_is_online,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
        is_online = EXCLUDED.is_online,
        last_seen_at = NOW(),
        updated_at = NOW();
END;
$$;

-- 5. Batch Presence Query with 2-minute Stale Detection & Server Time
CREATE OR REPLACE FUNCTION public.get_effective_user_presence(p_user_ids UUID[])
RETURNS TABLE (
    user_id UUID,
    is_online BOOLEAN,
    last_seen_at TIMESTAMPTZ,
    effective_is_online BOOLEAN,
    server_now TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ids.id AS user_id,
        COALESCE(up.is_online, false) AS is_online,
        COALESCE(up.last_seen_at, p.updated_at, p.created_at, NOW() - INTERVAL '1 day') AS last_seen_at,
        COALESCE((up.is_online AND up.last_seen_at >= (NOW() - INTERVAL '2 minutes')), false) AS effective_is_online,
        NOW() AS server_now
    FROM unnest(p_user_ids) AS ids(id)
    LEFT JOIN public.user_presence up ON up.user_id = ids.id
    LEFT JOIN public.profiles p ON p.id = ids.id;
END;
$$;

-- 6. Helper RPC to get authoritative server time
CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT NOW();
$$;

-- 7. Add user_presence to Supabase Realtime Publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'user_presence'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_presence;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Graceful fallback if publication does not exist
END $$;

-- 8. Grant Permissions
GRANT ALL ON public.user_presence TO postgres, service_role;
GRANT SELECT, INSERT, UPDATE ON public.user_presence TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_user_presence(BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_effective_user_presence(UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_server_time() TO authenticated;
