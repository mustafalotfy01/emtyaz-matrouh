const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function testFcmSend() {
  console.log('=== 1. Fetching Student FCM Token from Supabase ===');
  const studentId = '9a7ae527-9ca0-4e65-b784-a09ce1680360';
  const userRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${studentId}`, {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  const userData = await userRes.json();
  const token = userData.user_metadata?.fcm_token;

  console.log(`Student ID: ${studentId}`);
  console.log(`Has FCM Token: ${!!token}`);
  console.log(`Token length: ${token ? token.length : 0}`);

  if (!token) {
    console.error('Student does not have an FCM token!');
    return;
  }

  console.log('\n=== 2. Testing FCM Web Push Dispatch ===');
  // FCM Web endpoint: https://fcm.googleapis.com/fcm/send
  // Or Firebase Installations / Web push protocol
  console.log('Target endpoint format for token:', token.substring(0, 15) + '...');
}

testFcmSend();
