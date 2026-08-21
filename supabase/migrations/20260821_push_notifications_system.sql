-- ==============================================================================
-- MIGRATION: Push Notification Subscriptions, Campaigns, and Broadcast Engine
-- Date: 2026-08-21
-- Description: Complete Web Push / PWA / Device notification infrastructure
-- ==============================================================================

-- 1. Push Subscriptions Table
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

-- 2. Notification Campaigns Table
CREATE TABLE IF NOT EXISTS public.notification_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES public.profiles(id),
    audience_type TEXT NOT NULL, -- ALL_STUDENTS, GROUP_A, GROUP_B, DEPARTMENT, SPECIFIC_STUDENTS
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

-- 3. Notification Deliveries Table
CREATE TABLE IF NOT EXISTS public.notification_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campaign_id UUID NOT NULL REFERENCES public.notification_campaigns(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    push_subscription_id UUID REFERENCES public.push_subscriptions(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'delivered', -- delivered, failed, pending
    error TEXT,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_deliveries_campaign ON public.notification_deliveries(campaign_id);

-- 4. Ensure extra fields in notifications table
ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS sender_id UUID REFERENCES public.profiles(id),
    ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES public.notification_campaigns(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- 5. RLS Policies
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;

-- Subscriptions: User can view and manage their own subscriptions
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

-- Campaigns: Leaders, Doctors, Admins can view and create campaigns
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

-- Deliveries: Authorized staff can view deliveries
DROP POLICY IF EXISTS "Authorized staff can view deliveries" ON public.notification_deliveries;
CREATE POLICY "Authorized staff can view deliveries"
ON public.notification_deliveries FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role IN ('leader', 'evaluating_doctor', 'super_admin')
    )
);

-- 6. Server-Side Broadcast RPC Function
CREATE OR REPLACE FUNCTION public.send_broadcast_notification_rpc(
    p_sender_id UUID,
    p_audience_type TEXT,
    p_audience_value TEXT,
    p_title TEXT,
    p_body TEXT,
    p_type TEXT DEFAULT 'GENERAL',
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_specific_user_ids UUID[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sender_role TEXT;
    v_campaign_id UUID;
    v_recipient_ids UUID[] := '{}';
    v_recipient_id UUID;
    v_sub RECORD;
    v_recipient_count INT := 0;
    v_device_count INT := 0;
    v_subs_json JSONB := '[]'::jsonb;
BEGIN
    -- 1. Validate Sender Role
    SELECT role INTO v_sender_role FROM public.profiles WHERE id = p_sender_id;
    IF v_sender_role IS NULL OR v_sender_role NOT IN ('leader', 'evaluating_doctor', 'super_admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only Leaders, Supervisors, and Admins can broadcast notifications.';
    END IF;

    -- 2. Resolve Target Recipients
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
        -- Find students who have approved shifts in this department in the current or upcoming roster
        SELECT ARRAY_AGG(DISTINCT student_id) INTO v_recipient_ids
        FROM public.roster_entries
        WHERE department_id::text = p_audience_value AND status = 'approved';
        
        -- Fallback to all approved students if department entries are not yet populated
        IF v_recipient_ids IS NULL OR array_length(v_recipient_ids, 1) IS NULL THEN
            SELECT ARRAY_AGG(id) INTO v_recipient_ids
            FROM public.profiles
            WHERE role = 'student' AND (is_approved = true OR registration_status = 'approved');
        END IF;

    ELSIF p_audience_type = 'SPECIFIC_STUDENTS' THEN
        v_recipient_ids := p_specific_user_ids;
    ELSE
        RAISE EXCEPTION 'Invalid audience type: %', p_audience_type;
    END IF;

    IF v_recipient_ids IS NULL OR array_length(v_recipient_ids, 1) IS NULL THEN
        v_recipient_ids := '{}';
    END IF;

    v_recipient_count := COALESCE(array_length(v_recipient_ids, 1), 0);

    -- 3. Create Campaign Record
    INSERT INTO public.notification_campaigns (
        sender_id, audience_type, audience_value, title, body, type, metadata, recipient_count
    ) VALUES (
        p_sender_id, p_audience_type, p_audience_value, p_title, p_body, p_type, p_metadata, v_recipient_count
    ) RETURNING id INTO v_campaign_id;

    -- 4. Create In-App Notification Records
    IF v_recipient_count > 0 THEN
        FOREACH v_recipient_id IN ARRAY v_recipient_ids LOOP
            INSERT INTO public.notifications (
                user_id, sender_id, campaign_id, title, message, type, metadata, is_read, created_at
            ) VALUES (
                v_recipient_id, p_sender_id, v_campaign_id, p_title, p_body, p_type, p_metadata, false, NOW()
            );
        END LOOP;
    END IF;

    -- 5. Query Active Push Subscriptions & Register Deliveries
    IF v_recipient_count > 0 THEN
        FOR v_sub IN 
            SELECT ps.id AS sub_id, ps.user_id, ps.endpoint, ps.p256dh, ps.auth, ps.platform, ps.device_name
            FROM public.push_subscriptions ps
            WHERE ps.user_id = ANY(v_recipient_ids) AND ps.is_active = true
        LOOP
            v_device_count := v_device_count + 1;
            
            -- Insert delivery log
            INSERT INTO public.notification_deliveries (
                campaign_id, user_id, push_subscription_id, status, sent_at
            ) VALUES (
                v_campaign_id, v_sub.user_id, v_sub.sub_id, 'delivered', NOW()
            );

            -- Accumulate subscription object for Web Push dispatcher
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

    -- Update campaign device count and success count
    UPDATE public.notification_campaigns
    SET device_count = v_device_count,
        success_count = v_device_count
    WHERE id = v_campaign_id;

    -- 6. Return Execution Summary
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
