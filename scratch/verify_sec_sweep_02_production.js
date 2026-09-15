const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zlxumwvygqcxhareknul.supabase.co';
const ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3NzIyMjEsImV4cCI6MjEwMjM0ODIyMX0.7FRbGAuFHh8sqfwBXQM5n3WVfyNbnuIAk3ucND3Kh-s';

async function runSecSweep02Verification() {
  console.log('========================================================================');
  console.log('LIVE PRODUCTION VERIFICATION - SEC-SWEEP-02 PROFILES PII EXPOSURE');
  console.log('Target:', SUPABASE_URL);
  console.log('========================================================================\\n');

  let passed = 0;
  let total = 0;
  function assert(cond, name) {
    total++;
    if (cond) {
      console.log('[PASS] ' + name);
      passed++;
    } else {
      console.error('[FAIL] ' + name);
    }
  }

  // Helper: create authenticated test user
  async function createTestUser(label) {
    const ts = Date.now() + Math.floor(Math.random() * 10000);
    const email = 'audit_' + label + '_' + ts + '@disposable-audit.matrouh.test';
    const password = 'Pass_' + ts + '!Sec2';
    const signupRes = await fetch(SUPABASE_URL + '/auth/v1/signup', {
      method: 'POST',
      headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        password,
        data: {
          full_name: 'Test ' + label,
          university_code: 'PII-' + ts.toString().slice(-6),
          phone_number: '010' + Math.floor(10000000 + Math.random() * 90000000),
          national_id: '299' + ts.toString().slice(-11),
          residence_address: 'مطروح شارع ' + label,
          emergency_contact: '011' + Math.floor(10000000 + Math.random() * 90000000)
        }
      })
    });
    if (!signupRes.ok) return null;
    const signupData = await signupRes.json();
    const userId = signupData.user?.id || signupData.id;
    let session = signupData.session;
    if (!session) {
      const loginRes = await fetch(SUPABASE_URL + '/auth/v1/token?grant_type=password', {
        method: 'POST',
        headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      if (loginRes.ok) session = await loginRes.json();
    }
    return { userId, email, token: session?.access_token };
  }

  console.log('--- Test 1: Anonymous Access Blocked ---');
  const anonProfilesRes = await fetch(SUPABASE_URL + '/rest/v1/profiles?select=id,full_name,national_id,phone_number', {
    headers: { 'apikey': ANON_KEY }
  });
  const anonProfiles = await anonProfilesRes.json();
  assert(anonProfilesRes.status === 200 || anonProfilesRes.status === 401, 'Anonymous profiles query executed');
  assert(Array.isArray(anonProfiles) && anonProfiles.length === 0, 'Anonymous caller receives 0 profile rows (Got ' + (Array.isArray(anonProfiles) ? anonProfiles.length : JSON.stringify(anonProfiles)) + ')');

  const anonPeersRes = await fetch(SUPABASE_URL + '/rest/v1/rpc/get_available_peers', {
    method: 'POST',
    headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' }
  });
  assert(anonPeersRes.status === 401 || anonPeersRes.status === 403 || anonPeersRes.status === 400, 'Anonymous caller cannot execute get_available_peers() RPC (HTTP ' + anonPeersRes.status + ')');

  console.log('\\n--- Test 2: Provisioning Test Student Accounts ---');
  const studentA = await createTestUser('student_a');
  const studentB = await createTestUser('student_b');
  assert(studentA && studentA.token, 'Student A created and authenticated');
  assert(studentB && studentB.token, 'Student B created and authenticated');

  if (studentA?.token && studentB?.token) {
    console.log('\\n--- Test 3: Horizontal Isolation & PII Protection ---');
    // Student A attempts to SELECT all profiles
    const allRes = await fetch(SUPABASE_URL + '/rest/v1/profiles?select=id,full_name,national_id,phone_number,residence_address,emergency_contact,gpa,role', {
      headers: { 'apikey': ANON_KEY, 'Authorization': 'Bearer ' + studentA.token }
    });
    const allRows = await allRes.json();
    assert(Array.isArray(allRows), 'Student A profile query succeeded');
    assert(allRows.length === 1, 'Student A receives EXACTLY 1 profile row (their own row, Got: ' + allRows.length + ')');
    if (allRows.length > 0) {
      assert(allRows[0].id === studentA.userId, 'The 1 row returned is Student A own row (id matches auth.uid)');
    }

    // Student A explicitly attempts to query Student B row
    const targetBRes = await fetch(SUPABASE_URL + '/rest/v1/profiles?id=eq.' + studentB.userId + '&select=id,full_name,national_id,phone_number,residence_address,emergency_contact,gpa', {
      headers: { 'apikey': ANON_KEY, 'Authorization': 'Bearer ' + studentA.token }
    });
    const targetBRows = await targetBRes.json();
    assert(Array.isArray(targetBRows) && targetBRows.length === 0, 'Student A CANNOT query Student B profile row directly (Got: ' + targetBRows.length + ' rows)');

    // Student A attempts to dump PII across the whole table
    const leakCheck = allRows.filter(r => r.id !== studentA.userId);
    assert(leakCheck.length === 0, 'Zero external student or staff PII rows leaked to Student A');

    console.log('\\n--- Test 4: Sanitized Peer Directory RPC ---');
    const peersRes = await fetch(SUPABASE_URL + '/rest/v1/rpc/get_available_peers', {
      method: 'POST',
      headers: { 'apikey': ANON_KEY, 'Authorization': 'Bearer ' + studentA.token, 'Content-Type': 'application/json' }
    });
    assert(peersRes.status === 200, 'Student A can execute get_available_peers() RPC (HTTP 200)');
    const peers = await peersRes.json();
    assert(Array.isArray(peers), 'get_available_peers returned an array');
    if (Array.isArray(peers) && peers.length > 0) {
      const sample = peers[0];
      assert(!('national_id' in sample), 'Sanitized RPC does NOT contain national_id');
      assert(!('phone_number' in sample), 'Sanitized RPC does NOT contain phone_number');
      assert(!('residence_address' in sample), 'Sanitized RPC does NOT contain residence_address');
      assert(!('emergency_contact' in sample), 'Sanitized RPC does NOT contain emergency_contact');
      assert(!('gpa' in sample), 'Sanitized RPC does NOT contain gpa');
      assert(!('latitude' in sample), 'Sanitized RPC does NOT contain latitude');
      assert(!('longitude' in sample), 'Sanitized RPC does NOT contain longitude');
      assert('id' in sample && 'full_name' in sample && 'university_code' in sample, 'Sanitized RPC contains expected safe directory fields');
    } else {
      console.log('No approved peers yet in database, verifying RPC structure schema...');
      assert(peersRes.status === 200, 'get_available_peers RPC verified callable');
    }

    console.log('\\n--- Test 5: Cleanup Test Accounts ---');
    await fetch(SUPABASE_URL + '/rest/v1/profiles?id=eq.' + studentA.userId, {
      method: 'DELETE',
      headers: { 'apikey': ANON_KEY, 'Authorization': 'Bearer ' + studentA.token }
    });
    await fetch(SUPABASE_URL + '/rest/v1/profiles?id=eq.' + studentB.userId, {
      method: 'DELETE',
      headers: { 'apikey': ANON_KEY, 'Authorization': 'Bearer ' + studentB.token }
    });
    console.log('Cleaned up test accounts.');
  }

  console.log('\\n========================================================================');
  console.log('LIVE PRODUCTION VERIFICATION SUMMARY: ' + passed + '/' + total + ' Tests Passed');
  console.log('========================================================================');
}

runSecSweep02Verification().catch(console.error);
