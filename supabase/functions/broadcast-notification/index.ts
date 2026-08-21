// Supabase Edge Function: broadcast-notification
// Securely handles Leader/Admin notification broadcasts:
// 1. Validates Caller Authentication & Role (leader / super_admin / evaluating_doctor)
// 2. Inserts In-App Notification records in public.notifications using server-side Service Role
// 3. Dispatches Web Push Notifications to targeted student FCM tokens
// All private keys and service role credentials remain 100% on the server.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const ALLOWED_ORIGINS = [
  "http://localhost:8090",
  "http://localhost:8080",
  "http://localhost:3000",
  "http://127.0.0.1:8090",
  "http://127.0.0.1:8080",
  "http://127.0.0.1:3000",
  "https://emtaz-matrouh.vercel.app",
];

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("origin") || "";
  const isAllowed = ALLOWED_ORIGINS.includes(origin) || origin.startsWith("http://localhost:") || origin.startsWith("http://127.0.0.1:");
  const allowedOrigin = isAllowed ? origin : (ALLOWED_ORIGINS[0] || "*");

  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, ttl",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
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

  console.log("[EDGE_BROADCAST] REQUEST_RECEIVED");
  console.log(`[EDGE_BROADCAST] METHOD = ${req.method}`);
  console.log(`[EDGE_BROADCAST] ORIGIN = ${req.headers.get("origin") || "none"}`);

  // 1. Handle CORS Preflight immediately before authentication or payload parsing
  if (req.method === "OPTIONS") {
    console.log("[EDGE_BROADCAST] PREFLIGHT_REQUEST (OPTIONS 200 OK)");
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  console.log("[EDGE_BROADCAST] POST_REQUEST");

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      console.warn("[EDGE_BROADCAST] Missing Authorization header");
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
    console.log("[EDGE_BROADCAST] AUTH_CHECK_START");
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      console.warn("[EDGE_BROADCAST] Invalid JWT token:", userError);
      return new Response(JSON.stringify({ error: "Unauthorized: Invalid JWT token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    console.log("[EDGE_BROADCAST] AUTH_OK");

    // 4. Verify Leader / Admin Role from profiles table
    console.log("[EDGE_BROADCAST] ROLE_CHECK_START");
    const { data: callerProfile, error: profileError } = await adminClient
      .from("profiles")
      .select("id, full_name, role, is_approved, registration_status")
      .eq("id", user.id)
      .single();

    if (profileError || !callerProfile) {
      console.warn("[EDGE_BROADCAST] Caller profile not found:", profileError);
      return new Response(JSON.stringify({ error: "Forbidden: Caller profile not found" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`[EDGE_BROADCAST] ROLE = ${callerProfile.role}`);

    const allowedRoles = ["leader", "super_admin", "evaluating_doctor"];
    const isApproved = callerProfile.is_approved === true || callerProfile.registration_status === "approved";

    if (!allowedRoles.includes(callerProfile.role) || !isApproved) {
      console.warn(`[EDGE_BROADCAST] Role not permitted: role=${callerProfile.role}, isApproved=${isApproved}`);
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
    console.log("[EDGE_BROADCAST] TARGET_RESOLUTION_START");
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

    console.log(`[EDGE_BROADCAST] TARGET_COUNT = ${targetStudentIds.length}`);

    if (targetStudentIds.length === 0) {
      return new Response(JSON.stringify({ error: "No eligible recipient students found." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ──────────────────────────────────────────────────────────────────────────
    // PATH A: Insert In-App Notifications in Supabase (Service Role Owned)
    // ──────────────────────────────────────────────────────────────────────────
    console.log("[EDGE_BROADCAST] DB_INSERT_START");
    const inAppRows = targetStudentIds.map((studentId) => ({
      user_id: studentId,
      title: title.trim(),
      message: body.trim(),
      type: notification_type || "GENERAL",
      is_read: false,
      created_at: new Date().toISOString(),
    }));

    let inAppInserted = 0;
    const { error: insertError } = await adminClient.from("notifications").insert(inAppRows);
    if (!insertError) {
      inAppInserted = inAppRows.length;
      console.log(`[EDGE_BROADCAST] DB_INSERT_SUCCESS`);
      console.log(`[EDGE_BROADCAST] DB_INSERT_COUNT = ${inAppInserted}`);
    } else {
      console.error("[EDGE_BROADCAST] DB_INSERT_FAILED");
      console.error("[EDGE_BROADCAST] DB_ERROR = ", insertError);
      return new Response(JSON.stringify({ error: `Database insert failed: ${insertError.message}` }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ──────────────────────────────────────────────────────────────────────────
    // PATH B: Dispatch FCM Web Push Notifications
    // ──────────────────────────────────────────────────────────────────────────
    console.log("[EDGE_BROADCAST] TOKEN_LOOKUP_START");
    let pushSuccessCount = 0;
    let pushFailedCount = 0;
    let tokensFound = 0;

    for (const recipientId of targetStudentIds) {
      try {
        const maskedId = recipientId.length > 8 ? `${recipientId.substring(0, 8)}...` : recipientId;

        // Check user_metadata first, then push_subscriptions table
        let fcmToken: string | undefined;

        const { data: userData } = await adminClient.auth.admin.getUserById(recipientId);
        if (userData?.user?.user_metadata?.fcm_token) {
          fcmToken = userData.user.user_metadata.fcm_token;
        }

        if (!fcmToken) {
          const { data: subData } = await adminClient
            .from("push_subscriptions")
            .select("endpoint")
            .eq("user_id", recipientId)
            .eq("is_active", true)
            .order("updated_at", { ascending: false })
            .limit(1)
            .maybeSingle();

          if (subData?.endpoint?.startsWith("fcm:")) {
            fcmToken = subData.endpoint.replace("fcm:", "");
          }
        }

        if (!fcmToken || typeof fcmToken !== "string" || fcmToken.trim().length === 0) {
          console.log(`[EDGE_BROADCAST] TOKEN_FOUND = false for ${maskedId}`);
          pushFailedCount++;
          continue;
        }

        tokensFound++;
        console.log(`[EDGE_BROADCAST] TOKEN_FOUND = true for ${maskedId}`);

        // Send to FCM Web Push Endpoint
        console.log("[EDGE_BROADCAST] FCM_SEND_START");
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
          console.log(`[EDGE_BROADCAST] FCM_SUCCESS = ${maskedId}`);
        } else {
          pushFailedCount++;
          const respText = await fcmRes.text();
          console.warn(`[EDGE_BROADCAST] FCM_FAILED = ${fcmRes.status}: ${respText}`);
        }
      } catch (fcmErr) {
        pushFailedCount++;
        console.error(`[EDGE_BROADCAST] FCM_FAILED = exception:`, fcmErr);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        recipients: targetStudentIds.length,
        inAppInserted: inAppInserted,
        pushSent: pushSuccessCount,
        pushFailed: pushFailedCount,
        tokensFound: tokensFound,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[EDGE_BROADCAST] Top-level handler exception:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
