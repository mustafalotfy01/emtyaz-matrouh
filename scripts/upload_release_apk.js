const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { SUPABASE_URL, SERVICE_ROLE_KEY, adminRest } = require('./qa_test_helpers.js');

async function uploadApk() {
  const apkPath = path.join(__dirname, '../build/app/outputs/flutter-apk/app-release.apk');
  console.log('Reading APK from:', apkPath);
  const stats = fs.statSync(apkPath);
  console.log('APK Size:', (stats.size / (1024 * 1024)).toFixed(2), 'MB');

  const fileBuffer = fs.readFileSync(apkPath);
  const sha256 = crypto.createHash('sha256').update(fileBuffer).digest('hex');
  console.log('APK SHA256:', sha256);

  const uploadUrl = `${SUPABASE_URL}/storage/v1/object/app-releases/android/1.3/app-release.apk`;

  console.log('Uploading to Supabase Storage at:', uploadUrl);

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
  const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/app-releases/android/1.3/app-release.apk`;
  console.log('Public URL:', publicUrl);

  // Verify public download via HEAD request
  const headRes = await fetch(publicUrl, { method: 'HEAD' });
  console.log('Public URL HTTP Status:', headRes.status);
  console.log('Public URL Content-Type:', headRes.headers.get('content-type'));
  console.log('Public URL Content-Length:', headRes.headers.get('content-length'), 'bytes');

  // Update app_versions row for 1.3 (version_code 4)
  await adminRest('app_versions?version_code=eq.4', {
    method: 'PATCH',
    body: {
      apk_download_url: publicUrl,
      download_url: publicUrl,
      file_size: stats.size,
      file_name: 'app-release.apk',
      sha256: sha256,
      checksum: sha256,
      release_notes: '• تحديث نظام التواجد اللحظي وأوقات آخر ظهور دقيقة بالثواني\n• مزامنة الوقت الدقيق مع خوادم السيرفر وتوقيت القاهرة\n• تحسينات شاملة في استقرار وسرعة الاتصال اللحظي'
    }
  });

  console.log('Updated app_versions row for version 1.3 in database successfully!');
}

uploadApk().catch(err => console.error('Upload Error:', err));
