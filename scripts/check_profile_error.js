const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function testCompleteLifecycle() {
  const studentId = '11111111-2222-3333-4444-555555555555';
  console.log('=== 1. CREATING STUDENT IN PROFILES ===');
  const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    },
    body: JSON.stringify({
      id: studentId,
      email: 'live_test_student@matrouh.test',
      full_name: 'طالب الفحص النهائي الميداني',
      university_code: 'STD-LIVE-999',
      phone_number: '01099887766',
      emergency_contact: '01011223344',
      role: 'student',
      registration_status: 'pending',
      is_approved: false
    })
  });

  console.log('Insert HTTP Status:', insertRes.status);
  const created = await insertRes.json();
  console.log('Created Student:', created);

  console.log('\n=== 2. VERIFYING STUDENT APPEARS IN PROFILES LIST ===');
  const listRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${studentId}&select=*`, {
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` }
  });
  const listData = await listRes.json();
  console.log('Found in DB:', listData.length > 0 ? listData[0].full_name : 'NO');

  console.log('\n=== 3. DELETING STUDENT COMPLETELY ===');
  const delRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${studentId}`, {
    method: 'DELETE',
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` }
  });
  console.log('Delete HTTP Status:', delRes.status);

  console.log('\n=== 4. VERIFYING STUDENT IS 100% GONE ===');
  const checkRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${studentId}&select=*`, {
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` }
  });
  const checkData = await checkRes.json();
  console.log('Verification: Remaining matches =', checkData.length, checkData.length === 0 ? '--> SUCCESS: GONE!' : '--> FAILED');
}

testCompleteLifecycle();
