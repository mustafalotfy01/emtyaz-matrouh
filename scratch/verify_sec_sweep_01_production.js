const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zlxumwvygqcxhareknul.supabase.co';
const ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3NzIyMjEsImV4cCI6MjEwMjM0ODIyMX0.7FRbGAuFHh8sqfwBXQM5n3WVfyNbnuIAk3ucND3Kh-s';

async function runComprehensiveVerification() {
  console.log('========================================================================');
  console.log('LIVE PRODUCTION VERIFICATION — SEC-SWEEP-01 PRIVILEGE ESCALATION');
  console.log('Target:', SUPABASE_URL);
  console.log('========================================================================\n');

  let passed = 0;
  let total = 0;

  function assert(condition, testName) {
    total++;
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName}`);
    }
  }

  // Helper to test a specific payload and cleanup
  async function testPayload(name, metadata) {
    console.log(`\n--- Testing ${name} ---`);
    const ts = Date.now() + Math.floor(Math.random() * 1000);
    const email = `audit_test_${ts}@disposable-audit.matrouh.test`;
    const password = `P@ss_${ts}!Audit`;

    // 1. Signup
    const signupRes = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email,
        password,
        data: {
          full_name: `Test ${name}`,
          university_code: `AUD-${ts.toString().slice(-6)}`,
          ...metadata
        }
      })
    });

    if (!signupRes.ok) {
      assert(false, `${name}: Signup request failed (HTTP ${signupRes.status})`);
      return null;
    }

    const signupData = await signupRes.json();
    const userId = signupData.user?.id || signupData.id;

    // 2. Login to get authenticated session
    let session = signupData.session;
    if (!session) {
      const loginRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: {
          'apikey': ANON_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password })
      });
      if (loginRes.ok) {
        session = await loginRes.json();
      }
    }

    if (!session?.access_token) {
      assert(false, `${name}: Could not obtain session for user ${userId}`);
      return null;
    }

    // 3. Query profile from database
    const profileRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}&select=id,role,registration_status,is_approved`, {
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${session.access_token}`
      }
    });

    let profile = null;
    if (profileRes.ok) {
      const list = await profileRes.json();
      profile = list[0];
    }

    assert(profile !== null, `${name}: Profile record retrieved from database`);
    assert(profile?.role === 'student', `${name}: Authoritative role is strictly 'student' (Got: '${profile?.role}')`);
    assert(profile?.registration_status === 'pending', `${name}: Registration status is strictly 'pending' (Got: '${profile?.registration_status}')`);
    assert(profile?.is_approved === false, `${name}: is_approved is strictly false (Got: ${profile?.is_approved})`);

    // 4. Test get_auth_role()
    const roleRpcRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_auth_role`, {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${session.access_token}`,
        'Content-Type': 'application/json'
      }
    });
    const authRole = await roleRpcRes.json();
    assert(authRole === 'student', `${name}: get_auth_role() resolved strictly 'student' (Got: '${authRole}')`);

    // 5. Test privileged operation rejection (update_student_gpa)
    const gpaRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/update_student_gpa`, {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${session.access_token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        p_student_id: userId,
        p_new_gpa: 3.99
      })
    });
    assert(!gpaRes.ok, `${name}: Privileged Super Admin RPC was rejected (HTTP ${gpaRes.status})`);

    // 6. Cleanup disposable user
    try {
      await fetch(`${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}`, {
        method: 'DELETE',
        headers: {
          'apikey': ANON_KEY,
          'Authorization': `Bearer ${session.access_token}`
        }
      });
      console.log(`Cleaned up disposable profile for ${name}`);
    } catch (_) {}

    return profile;
  }

  // A) role = super_admin
  await testPayload('Scenario A: role=super_admin Injection', {
    role: 'super_admin'
  });

  // B) role = leader
  await testPayload('Scenario B: role=leader Injection', {
    role: 'leader'
  });

  // C) role = evaluating_doctor
  await testPayload('Scenario C: role=evaluating_doctor Injection', {
    role: 'evaluating_doctor'
  });

  // D) approval injection
  await testPayload('Scenario D: registration_status=approved & is_approved=true', {
    registration_status: 'approved',
    is_approved: true
  });

  // E) Combined malicious payload
  await testPayload('Scenario E: Combined Malicious Payload', {
    role: 'super_admin',
    registration_status: 'approved',
    is_approved: true
  });

  // 6. Verify existing administrative accounts remain intact
  console.log('\n--- Phase 6: Verifying Existing Privileged Accounts Unaltered ---');
  try {
    const adminCheckRes = await fetch(`${SUPABASE_URL}/rest/v1/profiles?role=in.(super_admin,leader,evaluating_doctor)&select=id,role,full_name,is_approved&limit=5`, {
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`
      }
    });
    if (adminCheckRes.ok) {
      const admins = await adminCheckRes.json();
      console.log(`Found ${admins.length} existing privileged profiles:`);
      admins.forEach(a => console.log(` - [${a.role}] ${a.full_name} (approved: ${a.is_approved})`));
      assert(admins.length > 0, `Existing admin/staff accounts are active and preserved in production`);
      assert(admins.every(a => a.is_approved === true), `Existing admin/staff accounts retain approved status`);
    } else {
      console.log('Note: Direct unauthenticated select on profiles returned:', adminCheckRes.status);
    }
  } catch (err) {
    console.log('Existing admin accounts check note:', err.message);
  }

  console.log('\n========================================================================');
  console.log(`FINAL PRODUCTION VERIFICATION SUMMARY: ${passed}/${total} Tests Passed`);
  console.log('========================================================================');
}

runComprehensiveVerification();
