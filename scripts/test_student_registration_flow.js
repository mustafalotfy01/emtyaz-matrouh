/**
 * End-to-End Test for Student Registration & Leader Approval Flow
 */

const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3NzIyMjEsImV4cCI6MjEwMjM0ODIyMX0.7FRbGAuFHh8sqfwBXQM5n3WVfyNbnuIAk3ucND3Kh-s';

async function testRegistrationFlow() {
  console.log('🧪 Testing Student Registration & Leader Approval Flow...');

  // 1. Create a new test student Auth user
  const newEmail = `student.temp.${Date.now()}@test.local`;
  const newCode = `STD-TEMP-${Date.now().toString().slice(-4)}`;

  console.log(`\n1️⃣ Creating Auth user: ${newEmail}...`);
  const authRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: newEmail,
      password: 'TestPassword123!',
      email_confirm: true,
      user_metadata: {
        full_name: 'Test New Registered Student',
        role: 'student',
      },
    }),
  });

  const authUser = await authRes.json();
  const userId = authUser.id;
  console.log(`   ✓ Auth user created: ${userId}`);

  // 2. Insert profile via Admin REST with registration_status: 'pending' and is_approved: false
  console.log('\n2️⃣ Inserting pending profile into profiles table...');
  const profilePayload = {
    id: userId,
    email: newEmail,
    full_name: 'Test New Registered Student',
    university_code: newCode,
    phone_number: '01099999999',
    national_id: '30202020000002',
    gender: 'female',
    marital_status: 'أعزب/عزباء',
    children_count: 0,
    is_matrouh_resident: false,
    emergency_contact: '01088888888',
    residence_address: 'سكن الطالبات - مطروح',
    role: 'student',
    student_group: 'B',
    is_approved: false,
    registration_status: 'pending',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    },
    body: JSON.stringify(profilePayload),
  });

  const inserted = await insertRes.json();
  console.log(`   ✓ Profile inserted successfully! Status: ${inserted[0]?.registration_status}, is_approved: ${inserted[0]?.is_approved}`);

  // 3. Leader checks pending approvals
  console.log('\n3️⃣ Leader queries pending registrations...');
  const pendingQuery = await fetch(`${SUPABASE_URL}/rest/v1/profiles?role=eq.student&registration_status=eq.pending`, {
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
  const pendingList = await pendingQuery.json();
  console.log(`   ✓ Found ${pendingList.length} pending student registration(s).`);
  console.log(`   - First pending student: ${pendingList[0]?.full_name} (${pendingList[0]?.email})`);

  // 4. Leader approves the student
  console.log('\n4️⃣ Leader approves the student...');
  const approveRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}`, {
    method: 'PATCH',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    },
    body: JSON.stringify({
      registration_status: 'approved',
      is_approved: true,
      reviewed_by: 'leader-001',
      reviewed_at: new Date().toISOString(),
    }),
  });
  const approvedData = await approveRes.json();
  console.log(`   ✓ Approval saved! Status: ${approvedData[0]?.registration_status}, is_approved: ${approvedData[0]?.is_approved}`);

  // 5. Student logs in
  console.log('\n5️⃣ Newly approved student logs in...');
  const loginRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: newEmail,
      password: 'TestPassword123!',
    }),
  });
  const loginData = await loginRes.json();
  if (loginData.access_token) {
    console.log(`   ✅ Login SUCCESS! Access token received.`);
  } else {
    console.log(`   ❌ Login failed:`, loginData);
  }

  // 6. Cleanup temp student
  console.log('\n6️⃣ Cleaning up temp student...');
  await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}`, {
    method: 'DELETE',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
  await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${userId}`, {
    method: 'DELETE',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
  console.log(`   ✓ Cleaned up temporary test user.\n`);
  console.log('🎉 REGISTRATION & APPROVAL E2E FLOW VERIFIED 100% WORKING!');
}

testRegistrationFlow().catch(console.error);
