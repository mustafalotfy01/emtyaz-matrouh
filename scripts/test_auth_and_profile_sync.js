const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function testFullAuthStudentFlow() {
  const timestamp = Date.now();
  const testEmail = `student_${timestamp}@matrouh.test`;
  const testCode = `STD-${timestamp.toString().slice(-4)}`;

  console.log(`=== 1. CREATING AUTH USER: ${testEmail} ===`);
  const authRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email: testEmail,
      password: 'Password123!',
      email_confirm: true,
      user_metadata: {
        full_name: 'طالب الفحص التلقائي الجديد',
        university_code: testCode,
        role: 'student',
        phone_number: '01012345678',
        registration_status: 'pending',
        is_approved: false
      }
    })
  });

  const authUser = await authRes.json();
  console.log('Auth Creation Status:', authRes.status, 'User ID:', authUser.id);
  if (!authUser.id) {
    console.error('Failed to create auth user:', authUser);
    return;
  }

  const studentId = authUser.id;

  // Insert profile with phone number
  console.log('\n=== 2. UPSERTING PROFILE ROW ===');
  const profRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=representation'
    },
    body: JSON.stringify({
      id: studentId,
      email: testEmail,
      full_name: 'طالب الفحص التلقائي الجديد',
      university_code: testCode,
      phone_number: '01012345678',
      emergency_contact: '01099887766',
      role: 'student',
      registration_status: 'pending',
      is_approved: false
    })
  });

  console.log('Profile Upsert Status:', profRes.status);

  // 3. Verify in profiles
  const getProfRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${studentId}&select=*`, {
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` }
  });
  const profData = await getProfRes.json();
  console.log('Profile verified in DB:', profData[0]?.full_name, 'Status:', profData[0]?.registration_status);

  // 4. Now test DELETION
  console.log('\n=== 3. DELETING STUDENT (CASCADE + PROFILE + AUTH) ===');
  // Cascade dependencies
  await fetch(`${SUPABASE_URL}/rest/v1/notifications?user_id=eq.${studentId}`, {
    method: 'DELETE',
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` }
  });
  
  // Delete Profile
  const delProfRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${studentId}`, {
    method: 'DELETE',
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` }
  });
  console.log('Delete Profile HTTP Status:', delProfRes.status);

  // Delete Auth User
  const delAuthRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${studentId}`, {
    method: 'DELETE',
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` }
  });
  console.log('Delete Auth HTTP Status:', delAuthRes.status);

  // 5. Final Verification
  const verifyProf = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${studentId}&select=*`, {
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` }
  });
  const verifyProfData = await verifyProf.json();
  console.log('Final Profile Verification (Must be 0):', verifyProfData.length, verifyProfData.length === 0 ? '--> SUCCESS: GONE!' : '--> STILL IN DB');

  const verifyAuth = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${studentId}`, {
    headers: { 'apikey': SERVICE_ROLE_KEY, 'Authorization': `Bearer ${SERVICE_ROLE_KEY}` }
  });
  console.log('Final Auth Verification (Must be 404):', verifyAuth.status, verifyAuth.status === 404 ? '--> SUCCESS: AUTH USER GONE!' : '--> STILL IN AUTH');
}

testFullAuthStudentFlow();
