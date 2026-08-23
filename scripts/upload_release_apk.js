const fs = require('fs');
const path = require('path');
const { SUPABASE_URL, SERVICE_ROLE_KEY, adminRest } = require('./qa_test_helpers.js');

async function uploadApk() {
  const apkPath = path.join(__dirname, '../build/app/outputs/apk/release/app-release.apk');
  console.log('Reading APK from:', apkPath);
  const stats = fs.statSync(apkPath);
  console.log('APK Size:', (stats.size / (1024 * 1024)).toFixed(2), 'MB');

  const uploadUrl = `${SUPABASE_URL}/storage/v1/object/app-releases/android/1.1.0/app-release.apk`;

  console.log('Uploading to Supabase Storage at:', uploadUrl);
  const fileBuffer = fs.readFileSync(apkPath);

  const res = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': 'Bearer ' + SERVICE_ROLE_KEY,
      'Content-Type': 'application/vnd.android.package-archive',
      'x-upsert': 'true'
    },
    body: fileBuffer
  });

  const uploadResult = await res.json();
  console.log('Upload Result:', uploadResult);

  // Direct public download URL
  const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/app-releases/android/1.1.0/app-release.apk`;
  console.log('Public URL:', publicUrl);

  // Verify public download via HEAD request
  const headRes = await fetch(publicUrl, { method: 'HEAD' });
  console.log('Public URL HTTP Status:', headRes.status);
  console.log('Public URL Content-Type:', headRes.headers.get('content-type'));
  console.log('Public URL Content-Length:', headRes.headers.get('content-length'), 'bytes');

  // Update app_versions row for 1.1.0 (version_code 2)
  await adminRest('app_versions?version_code=eq.2', {
    method: 'PATCH',
    body: {
      apk_download_url: publicUrl,
      file_size: stats.size,
      file_name: 'app-release.apk',
      release_notes: '• إصلاح نظام البصمة الفورية وتأكيد التواجد\n• تفعيل سجل الجزاءات والمكافآت للطلاب والليدرز\n• تحسينات عامة في الأداء واستقرار النظام'
    }
  });

  console.log('Updated app_versions row in database successfully!');
}

uploadApk().catch(err => console.error('Upload Error:', err));
