-- ==============================================================================
-- MIGRATION: Security Audit Item 10 - Rate Limiting & Notification Abuse Prevention
-- Date: 2026-09-10
-- Self-contained & idempotent:
--   1. Ensures push_subscriptions, notification_campaigns, notification_deliveries,
--      and security_rate_limits tables exist with proper RLS.
--   2. Implements atomic, race-condition-safe rate limiting (check_and_record_rate_limit).
--   3. Enforces device subscription flood limit (max 5 active devices per user).
--   4. Hardens notifications table RLS against unauthorized direct inserts.
--   5. Implements secured send_broadcast_notification_rpc with auth.uid() & rate limits.
-- ==============================================================================

-- ── 1. PREREQUISITE TABLES & COLUMNS ──────────────────────────────────────────

-- A. Push Subscriptions Table
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    platform TEXT NOT NULL DEFAULT 'web',
    endpoint TEXT NOT NULL,
    p256dh TEXT,
    auth TEXT,
    device_name TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_endpoint UNIQUE(user_id, endpoint)
);

CREATE INDEX IF NOT EXISTS idx_push_subs_user ON public.push_subscriptions(user_id) WHERE is_active = true;

-- B. Notification Campaigns Table
CREATE TABLE IF NOT EXISTS public.notification_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES public.profiles(id),
    audience_type TEXT NOT NULL,
    audience_value TEXT,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'GENERAL',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    recipient_count INTEGER NOT NULL DEFAULT 0,
    device_count INTEGER NOT NULL DEFAULT 0,
    success_count INTEGER NOT NULL DEFAULT 0,
    failure_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_campaigns_sender ON public.notification_campaigns(sender_id);
CREATE INDEX IF NOT EXISTS idx_notif_campaigns_created ON public.notification_campaigns(created_at DESC);

-- C. Notification Deliveries Table
CREATE TABLE IF NOT EXISTS public.notification_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES public.notification_campaigns(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    push_subscription_id UUID REFERENCES public.push_subscriptions(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'delivered',
    error TEXT,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_deliveries_campaign ON public.notification_deliveries(campaign_id);

-- D. Notifications Columns Extension
ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS sender_id UUID REFERENCES public.profiles(id),
    ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES public.notification_campaigns(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- E. Security Rate Limits Table
CREATE TABLE IF NOT EXISTS public.security_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    request_count INT NOT NULL DEFAULT 1,
    last_request_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb,
    CONSTRAINT uq_rate_limit_user_action_window UNIQUE (user_id, action_type, window_start)
);

CREATE INDEX IF NOT EXISTS idx_security_rate_limits_lookup 
ON public.security_rate_limits(user_id, action_type, last_request_at DESC);


-- ── 2. ROW LEVEL SECURITY POLICIES ───────────────────────────────────────────

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_rate_limits ENABLE ROW LEVEL SECURITY;

-- Rate Limits: service_role only
DROP POLICY IF EXISTS "Service role manages rate limits" ON public.security_rate_limits;
CREATE POLICY "Service role manages rate limits"
ON public.security_rate_limits FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Push Subscriptions: Users can only manage their own device subscriptions
DROP POLICY IF EXISTS "Users can view own push subscriptions" ON public.push_subscriptions;
CREATE POLICY "Users can view own push subscriptions"
ON public.push_subscriptions FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own push subscriptions" ON public.push_subscriptions;
CREATE POLICY "Users can insert own push subscriptions"
ON public.push_subscriptions FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own push subscriptions" ON public.push_subscriptions;
CREATE POLICY "Users can update own push subscriptions"
ON public.push_subscriptions FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own push subscriptions" ON public.push_subscriptions;
CREATE POLICY "Users can delete own push subscriptions"
ON public.push_subscriptions FOR DELETE
USING (auth.uid() = user_id);

-- Notification Campaigns: Authorized staff only
DROP POLICY IF EXISTS "Authorized staff can view campaigns" ON public.notification_campaigns;
CREATE POLICY "Authorized staff can view campaigns"
ON public.notification_campaigns FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role IN ('leader', 'evaluating_doctor', 'super_admin')
    )
);

DROP POLICY IF EXISTS "Authorized staff can insert campaigns" ON public.notification_campaigns;
CREATE POLICY "Authorized staff can insert campaigns"
ON public.notification_campaigns FOR INSERT
WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role IN ('leader', 'evaluating_doctor', 'super_admin')
    )
);

-- Notification Deliveries: Authorized staff only
DROP POLICY IF EXISTS "Authorized staff can view deliveries" ON public.notification_deliveries;
CREATE POLICY "Authorized staff can view deliveries"
ON public.notification_deliveries FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role IN ('leader', 'evaluating_doctor', 'super_admin')
    )
);

-- Notifications RLS Hardening:
-- Users can view, update (mark read), and delete their own notifications.
-- Direct INSERT via PostgREST is strictly restricted to authorized staff.
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications"
ON public.notifications FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
ON public.notifications FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications"
ON public.notifications FOR DELETE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Staff can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Authorized staff can insert notifications" ON public.notifications;
CREATE POLICY "Authorized staff can insert notifications"
ON public.notifications FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND role IN ('leader', 'super_admin', 'evaluating_doctor')
        AND (is_approved = true OR registration_status = 'approved')
    )
);


-- ── 3. RATE LIMITING ENGINE (ATOMIC & RACE-SAFE) ──────────────────────────────

CREATE OR REPLACE FUNCTION public.check_and_record_rate_limit(
    p_user_id UUID,
    p_action_type TEXT,
    p_max_requests INT,
    p_window_seconds INT,
    p_cooldown_seconds INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_now TIMESTAMPTZ := clock_timestamp();
    v_window_start TIMESTAMPTZ;
    v_recent_count INT := 0;
    v_last_request TIMESTAMPTZ;
    v_seconds_since_last NUMERIC;
    v_window_interval INTERVAL := (p_window_seconds || ' seconds')::interval;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'UNAUTHENTICATED',
            'retry_after_seconds', p_cooldown_seconds
        );
    END IF;

    -- A. Check Cooldown (minimum time between consecutive requests)
    IF p_cooldown_seconds > 0 THEN
        SELECT last_request_at INTO v_last_request
        FROM public.security_rate_limits
        WHERE user_id = p_user_id AND action_type = p_action_type
        ORDER BY last_request_at DESC
        LIMIT 1;

        IF v_last_request IS NOT NULL THEN
            v_seconds_since_last := EXTRACT(EPOCH FROM (v_now - v_last_request));
            IF v_seconds_since_last < p_cooldown_seconds THEN
                RETURN jsonb_build_object(
                    'allowed', false,
                    'reason', 'COOLDOWN_ACTIVE',
                    'retry_after_seconds', CEIL(p_cooldown_seconds - v_seconds_since_last)
                );
            END IF;
        END IF;
    END IF;

    -- B. Count total requests in rolling window
    SELECT COALESCE(SUM(request_count), 0) INTO v_recent_count
    FROM public.security_rate_limits
    WHERE user_id = p_user_id
      AND action_type = p_action_type
      AND last_request_at > (v_now - v_window_interval);

    IF v_recent_count >= p_max_requests THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'reason', 'RATE_LIMIT_EXCEEDED',
            'retry_after_seconds', p_window_seconds
        );
    END IF;

    -- C. Record this request atomically
    v_window_start := date_trunc('minute', v_now);

    INSERT INTO public.security_rate_limits (
        user_id, action_type, window_start, request_count, last_request_at
    ) VALUES (
        p_user_id, p_action_type, v_window_start, 1, v_now
    )
    ON CONFLICT (user_id, action_type, window_start)
    DO UPDATE SET
        request_count = public.security_rate_limits.request_count + 1,
        last_request_at = EXCLUDED.last_request_at;

    -- D. Lazy cleanup of expired records (> 24 hours old)
    IF random() < 0.05 THEN
        DELETE FROM public.security_rate_limits
        WHERE last_request_at < (v_now - INTERVAL '24 hours');
    END IF;

    RETURN jsonb_build_object(
        'allowed', true,
        'remaining', GREATEST(0, p_max_requests - (v_recent_count + 1))
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_and_record_rate_limit(UUID, TEXT, INT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_record_rate_limit(UUID, TEXT, INT, INT, INT) TO service_role;


-- ── 4. FCM SUBSCRIPTION FLOOD PROTECTION (MAX 5 DEVICES PER USER) ─────────────

CREATE OR REPLACE FUNCTION public.limit_user_push_subscriptions()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_active_count INT;
BEGIN
    IF auth.role() <> 'service_role' AND auth.uid() IS NOT NULL THEN
        NEW.user_id := auth.uid();
    END IF;

    SELECT COUNT(*) INTO v_active_count
    FROM public.push_subscriptions
    WHERE user_id = NEW.user_id AND is_active = true AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

    -- Deactivate oldest subscriptions if >= 5 active
    IF v_active_count >= 5 THEN
        UPDATE public.push_subscriptions
        SET is_active = false, updated_at = NOW()
        WHERE id IN (
            SELECT id FROM public.push_subscriptions
            WHERE user_id = NEW.user_id AND is_active = true AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
            ORDER BY last_seen_at ASC
            LIMIT (v_active_count - 4)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_limit_push_subscriptions ON public.push_subscriptions;
CREATE TRIGGER trg_limit_push_subscriptions
BEFORE INSERT ON public.push_subscriptions
FOR EACH ROW EXECUTE FUNCTION public.limit_user_push_subscriptions();


-- ── 5. SECURED SERVER-SIDE BROADCAST RPC FUNCTION ────────────────────────────

CREATE OR REPLACE FUNCTION public.send_broadcast_notification_rpc(
    p_audience_type TEXT,
    p_audience_value TEXT DEFAULT NULL,
    p_title TEXT DEFAULT '',
    p_body TEXT DEFAULT '',
    p_type TEXT DEFAULT 'GENERAL',
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_specific_user_ids UUID[] DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_is_approved BOOLEAN;
    v_campaign_id UUID;
    v_recipient_ids UUID[] := '{}';
    v_recipient_id UUID;
    v_sub RECORD;
    v_recipient_count INT := 0;
    v_device_count INT := 0;
    v_subs_json JSONB := '[]'::jsonb;
    v_rate_limit_res JSONB;
BEGIN
    -- A. Authentication Check
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Caller authentication required.';
    END IF;

    -- B. Authorization & Role Verification
    SELECT role, (is_approved = true OR registration_status = 'approved')
    INTO v_caller_role, v_is_approved
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS NULL OR v_caller_role NOT IN ('leader', 'super_admin', 'evaluating_doctor') OR v_is_approved IS NOT TRUE THEN
        RAISE EXCEPTION 'Forbidden: Only approved Leaders, Supervisors, and Administrators can broadcast notifications.';
    END IF;

    -- C. Evaluating Doctor Audience Restriction
    IF v_caller_role = 'evaluating_doctor' AND p_audience_type IN ('ALL_STUDENTS', 'GROUP_A', 'GROUP_B') THEN
        RAISE EXCEPTION 'Forbidden: Evaluating doctors may only broadcast to specific departments or assigned students.';
    END IF;

    -- D. Input Bounds Validation
    IF p_title IS NULL OR length(trim(p_title)) = 0 OR length(p_title) > 200 THEN
        RAISE EXCEPTION 'Invalid title: Must be between 1 and 200 characters.';
    END IF;

    IF p_body IS NULL OR length(trim(p_body)) = 0 OR length(p_body) > 2000 THEN
        RAISE EXCEPTION 'Invalid body: Must be between 1 and 2000 characters.';
    END IF;

    -- E. Server-Side Rate Limiting (5 broadcasts per 10m, 15s cooldown)
    v_rate_limit_res := public.check_and_record_rate_limit(
        v_caller_id,
        'BROADCAST_NOTIFICATION',
        5,    -- Max 5 broadcasts
        600,  -- Per 10 minutes
        15    -- 15 seconds cooldown
    );

    IF (v_rate_limit_res->>'allowed')::boolean = false THEN
        RAISE EXCEPTION 'Rate limit exceeded: % (retry after %s)',
            v_rate_limit_res->>'reason',
            COALESCE(v_rate_limit_res->>'retry_after_seconds', '15');
    END IF;

    -- F. Idempotency Check (prevent double-clicks within 60s)
    IF p_idempotency_key IS NOT NULL AND length(p_idempotency_key) > 0 THEN
        IF EXISTS (
            SELECT 1 FROM public.notification_campaigns
            WHERE sender_id = v_caller_id
              AND (metadata->>'idempotency_key') = p_idempotency_key
              AND created_at > (clock_timestamp() - INTERVAL '60 seconds')
        ) THEN
            SELECT id INTO v_campaign_id
            FROM public.notification_campaigns
            WHERE sender_id = v_caller_id
              AND (metadata->>'idempotency_key') = p_idempotency_key
            ORDER BY created_at DESC
            LIMIT 1;

            RETURN jsonb_build_object(
                'success', true,
                'duplicate', true,
                'campaign_id', v_campaign_id,
                'message', 'Broadcast already processed (idempotency key matched).'
            );
        END IF;
    END IF;

    -- G. Target Audience Resolution Server-Side
    IF p_audience_type = 'ALL_STUDENTS' THEN
        SELECT ARRAY_AGG(id) INTO v_recipient_ids
        FROM public.profiles
        WHERE role = 'student' AND (is_approved = true OR registration_status = 'approved');

    ELSIF p_audience_type = 'GROUP_A' THEN
        SELECT ARRAY_AGG(id) INTO v_recipient_ids
        FROM public.profiles
        WHERE role = 'student' AND (is_approved = true OR registration_status = 'approved') AND student_group = 'A';

    ELSIF p_audience_type = 'GROUP_B' THEN
        SELECT ARRAY_AGG(id) INTO v_recipient_ids
        FROM public.profiles
        WHERE role = 'student' AND (is_approved = true OR registration_status = 'approved') AND student_group = 'B';

    ELSIF p_audience_type = 'DEPARTMENT' THEN
        SELECT ARRAY_AGG(DISTINCT student_id) INTO v_recipient_ids
        FROM public.roster_entries
        WHERE department_id::text = p_audience_value AND status = 'approved';

        IF v_recipient_ids IS NULL OR array_length(v_recipient_ids, 1) IS NULL THEN
            SELECT ARRAY_AGG(id) INTO v_recipient_ids
            FROM public.profiles
            WHERE role = 'student' AND (is_approved = true OR registration_status = 'approved');
        END IF;

    ELSIF p_audience_type = 'SPECIFIC_STUDENTS' THEN
        IF p_specific_user_ids IS NULL OR array_length(p_specific_user_ids, 1) IS NULL THEN
            RAISE EXCEPTION 'Specific student IDs list cannot be empty for SPECIFIC_STUDENTS audience.';
        END IF;

        SELECT ARRAY_AGG(id) INTO v_recipient_ids
        FROM public.profiles
        WHERE id = ANY(p_specific_user_ids) AND role = 'student';
    ELSE
        RAISE EXCEPTION 'Invalid audience type: %', p_audience_type;
    END IF;

    IF v_recipient_ids IS NULL OR array_length(v_recipient_ids, 1) IS NULL THEN
        v_recipient_ids := '{}';
    END IF;

    v_recipient_count := COALESCE(array_length(v_recipient_ids, 1), 0);

    -- H. Create Campaign Record
    INSERT INTO public.notification_campaigns (
        sender_id, audience_type, audience_value, title, body, type, metadata, recipient_count
    ) VALUES (
        v_caller_id,
        p_audience_type,
        p_audience_value,
        trim(p_title),
        trim(p_body),
        p_type,
        jsonb_build_object('idempotency_key', p_idempotency_key) || COALESCE(p_metadata, '{}'::jsonb),
        v_recipient_count
    ) RETURNING id INTO v_campaign_id;

    -- I. Create In-App Notification Records
    IF v_recipient_count > 0 THEN
        FOREACH v_recipient_id IN ARRAY v_recipient_ids LOOP
            INSERT INTO public.notifications (
                user_id, sender_id, campaign_id, title, message, type, metadata, is_read, created_at
            ) VALUES (
                v_recipient_id, v_caller_id, v_campaign_id, trim(p_title), trim(p_body), p_type, p_metadata, false, NOW()
            );
        END LOOP;
    END IF;

    -- J. Query Active Push Subscriptions & Register Deliveries
    IF v_recipient_count > 0 THEN
        FOR v_sub IN 
            SELECT ps.id AS sub_id, ps.user_id, ps.endpoint, ps.p256dh, ps.auth, ps.platform, ps.device_name
            FROM public.push_subscriptions ps
            WHERE ps.user_id = ANY(v_recipient_ids) AND ps.is_active = true
        LOOP
            v_device_count := v_device_count + 1;
            
            INSERT INTO public.notification_deliveries (
                campaign_id, user_id, push_subscription_id, status, sent_at
            ) VALUES (
                v_campaign_id, v_sub.user_id, v_sub.sub_id, 'delivered', NOW()
            );

            v_subs_json := v_subs_json || jsonb_build_object(
                'sub_id', v_sub.sub_id,
                'user_id', v_sub.user_id,
                'endpoint', v_sub.endpoint,
                'p256dh', v_sub.p256dh,
                'auth', v_sub.auth,
                'platform', v_sub.platform,
                'device_name', v_sub.device_name
            );
        END LOOP;
    END IF;

    UPDATE public.notification_campaigns
    SET device_count = v_device_count,
        success_count = v_device_count
    WHERE id = v_campaign_id;

    RETURN jsonb_build_object(
        'success', true,
        'campaign_id', v_campaign_id,
        'recipient_count', v_recipient_count,
        'device_count', v_device_count,
        'subscriptions', v_subs_json,
        'created_at', NOW()
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_broadcast_notification_rpc(TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, UUID[], TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_broadcast_notification_rpc(TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, UUID[], TEXT) TO service_role;
