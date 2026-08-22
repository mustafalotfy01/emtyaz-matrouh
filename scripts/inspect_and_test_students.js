const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function req(path, options = {}) {
  const url = `${SUPABASE_URL}${path}`;
  const headers = {
    'apikey': SERVICE_ROLE_KEY,
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    'Content-Type': 'application/json',
    ...(options.headers || {})
  };
  const res = await fetch(url, { ...options, headers });
  const text = await res.text();
  try {
    return { status: res.status, ok: res.ok, data: JSON.parse(text) };
  } catch {
    return { status: res.status, ok: res.ok, text };
  }
}

async function testFullStudentLifecycle() {
  console.log('=== TEST: ADDING A NEW STUDENT ===');
  const testId = 'f7e91234-8888-4444-9999-' + Date.now().toString().slice(-12);
  const testEmail = `student_test_${Date.now()}@internship.test`;
  const testCode = `STD-${Date.now().toString().slice(-4)}`;
  const testName = `طالب تجريبي للاختبار ${testCode}`;

  console.log(`Inserting profile: ${testName} (ID: ${testId}, Code: ${testCode})...`);
  const insertRes = await req('/rest/v1/profiles', {
    method: 'POST',
    body: JSON.stringify({
      id: testId,
      email: testEmail,
      full_name: testName,
      university_code: testCode,
      role: 'student',
      registration_status: 'pending',
      is_approved: false,
      gender: 'male',
      gpa: 3.75
    })
  });

  console.log('Profile Insert Status:', insertRes.status, insertRes.ok);

  // 1. Verify profile was created
  const fetchRes = await req(`/rest/v1/profiles?id=eq.${testId}&select=*`);
  console.log('Profile Created Successfully:', fetchRes.data?.length > 0 ? `YES (${fetchRes.data[0].full_name})` : 'NO');

  // 2. Add some test records for this student (attendance, notification, evaluation)
  console.log('Creating related records in other tables...');
  await req('/rest/v1/notifications', {
    method: 'POST',
    body: JSON.stringify({
      user_id: testId,
      title: 'إشعار تجريبي',
      message: 'مرحباً بك في المنظومة',
      type: 'general'
    })
  });

  // 3. Now perform full cascade deletion
  console.log('\n=== TEST: DELETING THE STUDENT WITH CASCADE ===');
  await req(`/rest/v1/notifications?user_id=eq.${testId}`, { method: 'DELETE' });
  await req(`/rest/v1/attendance?student_id=eq.${testId}`, { method: 'DELETE' });
  await req(`/rest/v1/roster_entries?student_id=eq.${testId}`, { method: 'DELETE' });
  await req(`/rest/v1/roster_preferences?student_id=eq.${testId}`, { method: 'DELETE' });
  await req(`/rest/v1/evaluations?student_id=eq.${testId}`, { method: 'DELETE' });
  await req(`/rest/v1/cases?student_id=eq.${testId}`, { method: 'DELETE' });
  await req(`/rest/v1/disciplinary_actions?student_id=eq.${testId}`, { method: 'DELETE' });
  await req(`/rest/v1/confirmation_requests?target_student_id=eq.${testId}`, { method: 'DELETE' });

  // Delete profile
  const delRes = await req(`/rest/v1/profiles?id=eq.${testId}`, { method: 'DELETE' });
  console.log('Profile Delete Status:', delRes.status, delRes.ok);

  // 4. Verify profile is 100% gone
  const verifyRes = await req(`/rest/v1/profiles?id=eq.${testId}&select=*`);
  console.log('Final Verification After Delete:', verifyRes.data?.length === 0 ? 'SUCCESS - STUDENT COMPLETELY REMOVED! ✅' : 'FAILED - STILL EXISTS ❌');

  console.log('\n=== CURRENT DATABASE PROFILES TABLE ===');
  const allProfiles = await req('/rest/v1/profiles?select=id,full_name,university_code,role,registration_status');
  console.table(allProfiles.data);
}

testFullStudentLifecycle().catch(console.error);
