const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function checkStudents() {
  console.log('=== 1. PROFILES TABLE ===');
  const res = await fetch(SUPABASE_URL + '/rest/v1/profiles?select=id,email,full_name,role,is_approved,registration_status,student_group', {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  const data = await res.json();
  console.log(JSON.stringify(data, null, 2));

  console.log('\n=== 2. AUTH USERS METADATA & TOKENS ===');
  const authRes = await fetch(SUPABASE_URL + '/auth/v1/admin/users', {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  const authData = await authRes.json();
  authData.users.forEach(u => {
    const fcm = u.user_metadata?.fcm_token;
    console.log(`- ${u.email} [${u.id}] role: ${u.user_metadata?.role}`);
    console.log(`  FCM token present: ${!!fcm} (length: ${fcm ? fcm.length : 0})`);
  });

  console.log('\n=== 3. NOTIFICATIONS TABLE RECENT ROWS ===');
  const notifRes = await fetch(SUPABASE_URL + '/rest/v1/notifications?order=created_at.desc&limit=10', {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  const notifData = await notifRes.json();
  console.log(JSON.stringify(notifData, null, 2));
}

checkStudents();
