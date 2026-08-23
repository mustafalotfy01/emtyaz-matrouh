const https = require('https');
const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function testUpload(sizeMb) {
  return new Promise((resolve, reject) => {
    const totalBytes = sizeMb * 1024 * 1024;
    console.log(`\n--- Testing ${sizeMb} MB upload to Supabase Storage ---`);
    const path = `/storage/v1/object/app-releases/android/test-${sizeMb}mb/app-release.apk`;
    
    const url = new URL(SUPABASE_URL + path);
    const req = https.request({
      hostname: url.hostname,
      port: 443,
      path: url.pathname,
      method: 'POST',
      headers: {
        'apikey': SERVICE_ROLE_KEY,
        'Authorization': 'Bearer ' + SERVICE_ROLE_KEY,
        'Content-Type': 'application/vnd.android.package-archive',
        'x-upsert': 'true',
        'Content-Length': totalBytes
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`Status: ${res.statusCode} | Body: ${data}`);
        resolve(res.statusCode >= 200 && res.statusCode < 300);
      });
    });

    req.on('error', (err) => {
      console.error('Request error:', err.message);
      reject(err);
    });

    const chunkSize = 1024 * 1024; // 1 MB chunks
    let sent = 0;
    const chunk = Buffer.alloc(chunkSize, 0x41);

    function writeChunk() {
      while (sent < totalBytes) {
        const remaining = totalBytes - sent;
        const currentChunk = remaining < chunkSize ? chunk.subarray(0, remaining) : chunk;
        sent += currentChunk.length;
        const ok = req.write(currentChunk);
        if (sent % (5 * 1024 * 1024) === 0 || sent === totalBytes) {
          console.log(`Progress: ${(sent / (1024 * 1024)).toFixed(0)} MB / ${sizeMb} MB (${Math.round(sent / totalBytes * 100)}%)`);
        }
        if (!ok) {
          req.once('drain', writeChunk);
          return;
        }
      }
      req.end();
    }

    writeChunk();
  });
}

async function run() {
  try {
    await testUpload(5);
    await testUpload(25);
    await testUpload(55);
  } catch (e) {
    console.error('Error running test:', e);
  }
}

run();
