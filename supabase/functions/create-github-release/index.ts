// Supabase Edge Function: create-github-release
// Securely handles GitHub Release creation and APK Release Asset upload:
// 1. Authenticates caller JWT and enforces Super Admin authorization
// 2. Creates a GitHub Release (tag: v{version_name}) using server-side GITHUB_TOKEN
// 3. Uploads APK file binary to GitHub Release Assets
// 4. Computes SHA-256 integrity checksum
// 5. Inserts production release record into public.app_versions table
// Zero GitHub secrets or PAT tokens are ever exposed to the client.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";
import { crypto } from "https://deno.land/std@0.177.0/crypto/mod.ts";

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("origin") || "*";
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, ttl",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
  };
}

async function calculateSha256(buffer: Uint8Array): Promise<string> {
  const hashBuffer = await crypto.subtle.digest("SHA-256", buffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req);

  // 1. Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://zlxumwvygqcxhareknul.supabase.co";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const authHeader = req.headers.get("Authorization") || "";

    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Initialize Supabase Admin Client
    const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    });

    // 3. Authenticate User from JWT
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const { data: { user }, error: userError } = await adminClient.auth.getUser(jwt);

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized: Invalid session" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Verify Super Admin Role
    const { data: callerProfile, error: profileError } = await adminClient
      .from("profiles")
      .select("id, role, is_approved")
      .eq("id", user.id)
      .single();

    if (profileError || !callerProfile || callerProfile.role !== "super_admin") {
      return new Response(
        JSON.stringify({ error: "Forbidden: Only Super Administrators can publish application releases." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Check GitHub Configuration Secrets
    const githubToken = Deno.env.get("GITHUB_TOKEN");
    const githubOwner = Deno.env.get("GITHUB_OWNER") || "mustafalotfy01";
    const githubRepo = Deno.env.get("GITHUB_REPO") || "emtyaz-matrouh";

    if (!githubToken) {
      return new Response(
        JSON.stringify({
          error: "GitHub configuration missing: GITHUB_TOKEN secret is not configured in Supabase Edge Functions.",
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 6. Parse Multipart Form Data
    const contentType = req.headers.get("content-type") || "";
    let versionName = "";
    let versionCode = 0;
    let releaseNotes = "";
    let forceUpdate = false;
    let minimumSupportedVersion = 1;
    let isActive = true;
    let apkBytes: Uint8Array | null = null;
    let fileName = "app-release.apk";
    let directDownloadUrl: string | null = null;

    if (contentType.includes("multipart/form-data")) {
      const formData = await req.formData();
      versionName = (formData.get("version_name") as string)?.trim() || "";
      versionCode = parseInt((formData.get("version_code") as string) || "0", 10);
      releaseNotes = (formData.get("release_notes") as string)?.trim() || "";
      forceUpdate = formData.get("force_update") === "true" || formData.get("force_update") === "1";
      minimumSupportedVersion = parseInt((formData.get("minimum_supported_version") as string) || "1", 10);
      isActive = formData.get("is_active") !== "false";
      directDownloadUrl = (formData.get("direct_download_url") as string)?.trim() || null;

      const fileEntry = formData.get("file");
      if (fileEntry && fileEntry instanceof File) {
        fileName = fileEntry.name || fileName;
        const arrayBuf = await fileEntry.arrayBuffer();
        apkBytes = new Uint8Array(arrayBuf);
      }
    } else {
      const jsonBody = await req.json();
      versionName = jsonBody.version_name?.trim() || "";
      versionCode = parseInt(jsonBody.version_code || "0", 10);
      releaseNotes = jsonBody.release_notes?.trim() || "";
      forceUpdate = jsonBody.force_update === true;
      minimumSupportedVersion = parseInt(jsonBody.minimum_supported_version || "1", 10);
      isActive = jsonBody.is_active !== false;
      directDownloadUrl = jsonBody.direct_download_url?.trim() || null;
      fileName = jsonBody.file_name || fileName;

      if (jsonBody.apk_base64) {
        const binaryStr = atob(jsonBody.apk_base64);
        apkBytes = new Uint8Array(binaryStr.length);
        for (let i = 0; i < binaryStr.length; i++) {
          apkBytes[i] = binaryStr.charCodeAt(i);
        }
      }
    }

    // 7. Validate inputs
    if (!versionName || versionCode <= 0) {
      return new Response(
        JSON.stringify({ error: "اسم الإصدار ورقم البناء (version_code) مطلوبان بشكل صحيح." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check for duplicate version_code in database
    const { data: existingCode } = await adminClient
      .from("app_versions")
      .select("id, version_code, version_name")
      .eq("platform", "android")
      .eq("version_code", versionCode)
      .maybeSingle();

    if (existingCode) {
      return new Response(
        JSON.stringify({
          error: `رقم البناء (${versionCode}) مسجل بالفعل للإصدار (${existingCode.version_name}). يرجى زيادة رقم البناء.`,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const tagName = `v${versionName}`;
    const releaseTitle = `Release v${versionName} (Build #${versionCode})`;

    let githubReleaseId: number | null = null;
    let githubAssetId: number | null = null;
    let releaseHtmlUrl: string | null = null;
    let finalDownloadUrl: string | null = directDownloadUrl;
    let sha256Checksum: string | null = null;
    let finalFileSize = apkBytes ? apkBytes.length : 0;

    // 8. Create GitHub Release via GitHub REST API v3
    const createReleaseRes = await fetch(
      `https://api.github.com/repos/${githubOwner}/${githubRepo}/releases`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${githubToken}`,
          "Accept": "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28",
          "Content-Type": "application/json",
          "User-Agent": "Nurse-Matrouh-Release-Manager",
        },
        body: JSON.stringify({
          tag_name: tagName,
          target_commitish: "main",
          name: releaseTitle,
          body: releaseNotes || `Production Android release ${releaseTitle}`,
          draft: false,
          prerelease: false,
          generate_release_notes: false,
        }),
      }
    );

    const releaseData = await createReleaseRes.json();

    if (!createReleaseRes.ok) {
      // If tag already exists, look up existing release
      if (createReleaseRes.status === 422 && releaseData?.errors?.[0]?.code === "already_exists") {
        const getExistingRes = await fetch(
          `https://api.github.com/repos/${githubOwner}/${githubRepo}/releases/tags/${tagName}`,
          {
            headers: {
              "Authorization": `Bearer ${githubToken}`,
              "Accept": "application/vnd.github+json",
              "User-Agent": "Nurse-Matrouh-Release-Manager",
            },
          }
        );
        if (getExistingRes.ok) {
          const existingRelease = await getExistingRes.json();
          githubReleaseId = existingRelease.id;
          releaseHtmlUrl = existingRelease.html_url;
        } else {
          return new Response(
            JSON.stringify({ error: `فشل في ربط الإصدار بالتاج الموجود على GitHub: ${releaseData.message}` }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      } else {
        return new Response(
          JSON.stringify({ error: `فشل إنشاء GitHub Release (${createReleaseRes.status}): ${releaseData.message || "Unknown error"}` }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else {
      githubReleaseId = releaseData.id;
      releaseHtmlUrl = releaseData.html_url;
    }

    // 9. Upload APK Asset to GitHub Release if binary provided
    if (apkBytes && apkBytes.length > 0 && githubReleaseId) {
      sha256Checksum = await calculateSha256(apkBytes);
      const sanitizedName = fileName.replaceAll(" ", "_");

      const uploadAssetUrl = `https://uploads.github.com/repos/${githubOwner}/${githubRepo}/releases/${githubReleaseId}/assets?name=${encodeURIComponent(sanitizedName)}`;

      const uploadAssetRes = await fetch(uploadAssetUrl, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${githubToken}`,
          "Accept": "application/vnd.github+json",
          "Content-Type": "application/vnd.android.package-archive",
          "Content-Length": apkBytes.length.toString(),
          "User-Agent": "Nurse-Matrouh-Release-Manager",
        },
        body: apkBytes,
      });

      const assetData = await uploadAssetRes.json();

      if (!uploadAssetRes.ok) {
        return new Response(
          JSON.stringify({ error: `فشل رفع حزمة APK كـ GitHub Release Asset (${uploadAssetRes.status}): ${assetData.message || "Unknown error"}` }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      githubAssetId = assetData.id;
      finalDownloadUrl = assetData.browser_download_url;
      finalFileSize = assetData.size || apkBytes.length;
    } else if (!finalDownloadUrl) {
      // Default direct asset URL convention if only release was created
      finalDownloadUrl = `https://github.com/${githubOwner}/${githubRepo}/releases/download/${tagName}/${fileName.replaceAll(" ", "_")}`;
    }

    // 10. Deactivate previous active releases if this release is marked active
    if (isActive) {
      await adminClient
        .from("app_versions")
        .update({ is_active: false })
        .eq("platform", "android")
        .eq("is_active", true);
    }

    // 11. Save Release Metadata into public.app_versions table
    const dbPayload = {
      version_name: versionName,
      version_code: versionCode,
      apk_download_url: finalDownloadUrl,
      download_url: finalDownloadUrl,
      release_notes: releaseNotes,
      force_update: forceUpdate,
      minimum_supported_version: minimumSupportedVersion,
      is_active: isActive,
      platform: "android",
      file_name: fileName,
      file_size: finalFileSize,
      sha256: sha256Checksum,
      github_release_id: githubReleaseId,
      github_tag_name: tagName,
      github_asset_id: githubAssetId,
      release_url: releaseHtmlUrl,
      created_by: user.id,
      release_date: new Date().toISOString(),
      published_at: new Date().toISOString(),
    };

    const { data: insertedRecord, error: dbError } = await adminClient
      .from("app_versions")
      .insert(dbPayload)
      .select()
      .single();

    if (dbError) {
      return new Response(
        JSON.stringify({ error: `تم إنشاء GitHub Release ولكن تعذر حفظ البيانات في قاعدة البيانات: ${dbError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: insertedRecord,
        download_url: finalDownloadUrl,
        release_url: releaseHtmlUrl,
        tag_name: tagName,
        version_code: versionCode,
        file_size: finalFileSize,
        sha256: sha256Checksum,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error during release creation." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
