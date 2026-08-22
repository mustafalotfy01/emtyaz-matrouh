// Supabase Edge Function: broadcast-notification
// Securely handles Leader/Admin notification broadcasts:
// 1. Validates Caller Authentication & Role (leader / super_admin / evaluating_doctor)
// 2. Inserts In-App Notification records in public.notifications using server-side Service Role
// 3. Dispatches Web Push Notifications to targeted student FCM tokens via FCM HTTP v1
// All private keys and service role credentials remain 100% on the server.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("origin") || "*";

  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, ttl",
    "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
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

// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE OAUTH2 ACCESS TOKEN GENERATOR FOR FCM HTTP v1
// ─────────────────────────────────────────────────────────────────────────────
function base64UrlEncode(str: string | Uint8Array): string {
  let binary = "";
  if (typeof str === "string") {
    const bytes = new TextEncoder().encode(str);
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
  } else {
    for (let i = 0; i < str.byteLength; i++) {
      binary += String.fromCharCode(str[i]);
    }
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64Lines = pem.replace(/-----BEGIN[ A-Z_-]+-----/g, "").replace(/-----END[ A-Z_-]+-----/g, "").replace(/\s+/g, "");
  const b64 = atob(b64Lines);
  const u8 = new Uint8Array(b64.length);
  for (let i = 0; i < b64.length; i++) {
    u8[i] = b64.charCodeAt(i);
  }
  return u8.buffer;
}

async function getGoogleOAuth2AccessToken(clientEmail: string, privateKeyPem: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaimSet}`;

  // Import Private Key (PKCS8)
  const binaryDer = pemToArrayBuffer(privateKeyPem);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signedJwt = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;

  // Exchange JWT for Access Token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  const tokenData = await tokenRes.json();
  if (!tokenRes.ok || !tokenData.access_token) {
    throw new Error(`Google OAuth2 Error: ${JSON.stringify(tokenData)}`);
  }

  return tokenData.access_token;
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
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://zlxumwvygqcxhareknul.supabase.co";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization") || "";

    if (!authHeader) {
      console.warn("[EDGE_BROADCAST] Missing Authorization header");
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Initialize Admin Client
    const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    // 3. Authenticate Caller using JWT token
    console.log("[EDGE_BROADCAST] AUTH_CHECK_START");
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: { user }, error: userError } = await adminClient.auth.getUser(jwt);

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
    // PATH A: Insert In-App Notifications in Supabase (Server-Side Owned)
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
    // PATH B: Dispatch FCM Web Push Notifications via FCM HTTP v1
    // ──────────────────────────────────────────────────────────────────────────
    console.log("[EDGE_BROADCAST] TOKEN_LOOKUP_START");
    let pushSuccessCount = 0;
    let pushFailedCount = 0;
    let tokensFound = 0;
    let tokensMissing = 0;
    let fcmAttempts = 0;

    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID") || "emtaz-matrouh";
    let firebaseOAuthToken: string | null = null;

    // Load Service Account if provided in Supabase Secrets
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
    const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");

    try {
      if (serviceAccountJson) {
        const sa = JSON.parse(serviceAccountJson);
        firebaseOAuthToken = await getGoogleOAuth2AccessToken(sa.client_email, sa.private_key);
      } else if (clientEmail && privateKey) {
        firebaseOAuthToken = await getGoogleOAuth2AccessToken(clientEmail, privateKey.replace(/\\n/g, "\n"));
      }
    } catch (authErr) {
      console.warn("[EDGE_BROADCAST] Google OAuth2 Token Generation Note:", authErr);
    }

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
          try {
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
          } catch (_) {}
        }

        if (!fcmToken || typeof fcmToken !== "string" || fcmToken.trim().length === 0) {
          console.log(`[EDGE_BROADCAST] TOKEN_FOUND = false for ${maskedId}`);
          tokensMissing++;
          continue;
        }

        tokensFound++;
        fcmAttempts++;
        console.log(`[EDGE_BROADCAST] TOKEN_FOUND = true for ${maskedId} (length: ${fcmToken.length})`);
        console.log(`[EDGE_BROADCAST] FCM_REQUEST_START for ${maskedId}`);

        let fcmStatus = 0;
        let fcmBody = "";

        if (firebaseOAuthToken) {
          // Send via FCM HTTP v1
          const httpV1Payload = {
            message: {
              token: fcmToken,
              notification: {
                title: title.trim(),
                body: body.trim(),
              },
              webpush: {
                notification: {
                  title: title.trim(),
                  body: body.trim(),
                  icon: "/icons/icon-192x192.png",
                  badge: "/icons/icon-192x192.png",
                  tag: "matrouh-notification",
                  renotify: true,
                },
                fcm_options: {
                  link: `https://emtaz-matrouh.vercel.app${target_route || "/"}`,
                },
              },
              data: {
                route: target_route || "/",
                type: notification_type || "GENERAL",
                sender_id: user.id,
                sender_name: callerProfile.full_name,
                ...metadata,
              },
            },
          };

          const fcmRes = await fetch(
            `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
            {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${firebaseOAuthToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify(httpV1Payload),
            }
          );

          fcmStatus = fcmRes.status;
          fcmBody = await fcmRes.text();
        } else {
          // Direct WebPush endpoint delivery
          const directRes = await fetch(`https://fcm.googleapis.com/fcm/send/${fcmToken}`, {
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
          fcmStatus = directRes.status;
          fcmBody = await directRes.text();
        }

        console.log(`[EDGE_BROADCAST] FCM_RESPONSE_STATUS = ${fcmStatus}`);
        console.log(`[EDGE_BROADCAST] FCM_RESPONSE_BODY = ${fcmBody.substring(0, 200)}`);

        if (fcmStatus === 200 || fcmStatus === 201) {
          pushSuccessCount++;
          console.log(`[EDGE_BROADCAST] FCM_SUCCESS = ${maskedId}`);
        } else {
          pushFailedCount++;
          console.warn(`[EDGE_BROADCAST] FCM_FAILED = ${maskedId} (Status ${fcmStatus}): ${fcmBody}`);

          // Handle stale tokens (UNREGISTERED)
          if (fcmBody.includes("UNREGISTERED") || fcmBody.includes("not a valid FCM registration token")) {
            console.log(`[EDGE_BROADCAST] Removing invalid/stale token for ${maskedId}`);
            try {
              await adminClient.auth.admin.updateUserById(recipientId, {
                user_metadata: { fcm_token: null },
              });
            } catch (_) {}
          }
        }
      } catch (fcmErr) {
        pushFailedCount++;
        console.error(`[EDGE_BROADCAST] FCM_FAILED = exception:`, fcmErr);
      }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // PATH C: Insert Sender Broadcast History Record in notifications (Server-Side Owned)
    // ──────────────────────────────────────────────────────────────────────────
    try {
      await adminClient.from("notifications").insert({
        user_id: user.id,
        title: title.trim(),
        message: body.trim(),
        type: notification_type || "GENERAL",
        is_read: true,
        created_at: new Date().toISOString(),
        metadata: {
          is_broadcast_campaign: true,
          sender_id: user.id,
          sender_name: callerProfile.full_name,
          sender_role: callerProfile.role,
          audience_type: audience_type,
          audience_value: audience_value,
          target_route: target_route,
          recipient_count: targetStudentIds.length,
          device_count: tokensFound,
          success_count: pushSuccessCount,
          failure_count: pushFailedCount,
          sent_at: new Date().toISOString(),
          ...metadata,
        }
      });
      console.log("[EDGE_BROADCAST] SENDER_CAMPAIGN_RECORD_SAVED");
    } catch (senderRecordErr) {
      console.warn("[EDGE_BROADCAST] Failed to save sender campaign record:", senderRecordErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        recipients: targetStudentIds.length,
        inAppInserted: inAppInserted,
        pushSent: pushSuccessCount,
        pushFailed: pushFailedCount,
        tokensFound: tokensFound,
        tokensMissing: tokensMissing,
        fcmAttempts: fcmAttempts,
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
