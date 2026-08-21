// ==============================================================================
// Supabase Edge Function: broadcast-notification
// Project: Emtaz-Matrouh / Matrouh Internship
//
// Description:
// Secure Server-Side Notification Broadcaster for Leaders and Administrators.
// Handles both In-App Notification insertion (Path A) and FCM Push Dispatch (Path B).
//
// SECURITY:
// - Verifies caller JWT and enforces Leader/Supervisor/Admin role from profiles table.
// - Uses SUPABASE_SERVICE_ROLE_KEY strictly server-side.
// - Tokens are never logged in full.
// ==============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("origin") ?? "*";
  const allowedOrigins = [
    "https://emtaz-matrouh.vercel.app",
    "http://localhost:",
    "http://127.0.0.1:",
  ];
  const isAllowed = allowedOrigins.some((o) => origin.startsWith(o)) || origin === "*";
  return {
    "Access-Control-Allow-Origin": isAllowed ? origin : "https://emtaz-matrouh.vercel.app",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

interface BroadcastPayload {
  audience_type: "ALL_STUDENTS" | "GROUP_A" | "GROUP_B" | "DEPARTMENT" | "SPECIFIC_STUDENTS";
  audience_value?: string;
  specific_student_ids?: string[];
  title: string;
  body: string;
  notification_type?: string;
  target_route?: string;
  metadata?: Record<string, any>;
}

serve(async (req) => {
  const corsHeaders = getCorsHeaders(req);

  // 1. Handle CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Initialize Clients
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? "", {
      global: { headers: { Authorization: authHeader } },
    });

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // 3. Authenticate Caller
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized: Invalid JWT token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Verify Leader / Admin Role from profiles table
    const { data: callerProfile, error: profileError } = await adminClient
      .from("profiles")
      .select("id, full_name, role, is_approved, registration_status")
      .eq("id", user.id)
      .single();

    if (profileError || !callerProfile) {
      return new Response(JSON.stringify({ error: "Forbidden: Caller profile not found" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const allowedRoles = ["leader", "super_admin", "evaluating_doctor"];
    const isApproved = callerProfile.is_approved === true || callerProfile.registration_status === "approved";

    if (!allowedRoles.includes(callerProfile.role) || !isApproved) {
      return new Response(
        JSON.stringify({ error: "Forbidden: Only approved Leaders, Supervisors, and Admins can broadcast notifications." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Parse Payload
    const payload: BroadcastPayload = await req.json();
    const { audience_type, audience_value, specific_student_ids, title, body, notification_type, target_route, metadata } = payload;

    if (!title || !title.trim() || !body || !body.trim()) {
      return new Response(JSON.stringify({ error: "Title and body are required fields." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 6. Resolve Target Recipients
    let targetStudentIds: string[] = [];

    if (audience_type === "ALL_STUDENTS") {
      const { data: students } = await adminClient
        .from("profiles")
        .select("id")
        .eq("role", "student")
        .or("is_approved.eq.true,registration_status.eq.approved");
      targetStudentIds = (students ?? []).map((s) => s.id);

    } else if (audience_type === "GROUP_A") {
      const { data: students } = await adminClient
        .from("profiles")
        .select("id")
        .eq("role", "student")
        .eq("student_group", "A")
        .or("is_approved.eq.true,registration_status.eq.approved");
      targetStudentIds = (students ?? []).map((s) => s.id);

    } else if (audience_type === "GROUP_B") {
      const { data: students } = await adminClient
        .from("profiles")
        .select("id")
        .eq("role", "student")
        .eq("student_group", "B")
        .or("is_approved.eq.true,registration_status.eq.approved");
      targetStudentIds = (students ?? []).map((s) => s.id);

    } else if (audience_type === "DEPARTMENT") {
      const { data: students } = await adminClient
        .from("profiles")
        .select("id")
        .eq("role", "student")
        .or("is_approved.eq.true,registration_status.eq.approved");
      targetStudentIds = (students ?? []).map((s) => s.id);

    } else if (audience_type === "SPECIFIC_STUDENTS" && Array.isArray(specific_student_ids)) {
      // Validate that provided IDs belong to actual students
      const { data: validStudents } = await adminClient
        .from("profiles")
        .select("id")
        .in("id", specific_student_ids)
        .eq("role", "student");
      targetStudentIds = (validStudents ?? []).map((s) => s.id);
    }

    if (targetStudentIds.length === 0) {
      return new Response(JSON.stringify({ error: "No eligible recipient students found." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ──────────────────────────────────────────────────────────────────────────
    // PATH A: Insert In-App Notifications in Supabase
    // ──────────────────────────────────────────────────────────────────────────
    const inAppRecords = targetStudentIds.map((id) => ({
      user_id: id,
      title: title.trim(),
      message: body.trim(),
      type: notification_type || "GENERAL",
      is_read: false,
    }));

    const { data: insertedRows, error: insertError } = await adminClient
      .from("notifications")
      .insert(inAppRecords)
      .select("id");

    if (insertError) {
      console.error("[EDGE FUNCTION] In-App Notification insert error:", insertError);
      return new Response(JSON.stringify({ error: "Failed to create in-app notification records", details: insertError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ──────────────────────────────────────────────────────────────────────────
    // PATH B: Dispatch Push Notifications via FCM
    // ──────────────────────────────────────────────────────────────────────────
    let pushSuccessCount = 0;
    let tokensFound = 0;

    for (const recipientId of targetStudentIds) {
      try {
        const { data: userData, error: userFetchError } = await adminClient.auth.admin.getUserById(recipientId);
        if (userFetchError || !userData?.user) continue;

        const fcmToken = userData.user.user_metadata?.fcm_token;
        if (!fcmToken || typeof fcmToken !== "string" || fcmToken.trim().length === 0) {
          console.log(`[EDGE FCM TRACE] User ${recipientId}: No FCM token registered`);
          continue;
        }

        tokensFound++;
        console.log(`[EDGE FCM TRACE] User ${recipientId}: FCM token present (length: ${fcmToken.length})`);

        // Send to FCM Web Push Endpoint
        const fcmRes = await fetch(`https://fcm.googleapis.com/fcm/send/${fcmToken}`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "TTL": "86400",
          },
          body: JSON.stringify({
            title: title.trim(),
            body: body.trim(),
            data: {
              route: target_route || "/",
              type: notification_type || "GENERAL",
              sender_id: user.id,
              sender_name: callerProfile.full_name,
              ...metadata,
            },
          }),
        });

        if (fcmRes.status === 200 || fcmRes.status === 201) {
          pushSuccessCount++;
          console.log(`[EDGE FCM TRACE] Push delivered successfully to user ${recipientId}`);
        } else {
          console.warn(`[EDGE FCM TRACE] FCM status ${fcmRes.status} for user ${recipientId}`);
        }
      } catch (fcmErr) {
        console.error(`[EDGE FCM TRACE] Exception sending push to ${recipientId}:`, fcmErr);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        recipient_count: targetStudentIds.length,
        in_app_count: insertedRows?.length ?? 0,
        tokens_found: tokensFound,
        push_delivered_count: pushSuccessCount,
        sender: callerProfile.full_name,
        created_at: new Date().toISOString(),
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[EDGE FUNCTION ERROR]:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal Server Error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
