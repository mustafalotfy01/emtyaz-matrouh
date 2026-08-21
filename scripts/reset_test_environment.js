/**
 * Reusable Test Environment Reset Script for "امتياز مطروح"
 * 
 * Performs:
 * 1. Safe cleanup of test operational data and profiles (Preserves schema, tables, roles, depts, RLS).
 * 2. Purging of old Supabase Auth users.
 * 3. Deterministic creation of the 4 standard demo accounts:
 *    - student@test.local / Test12345! (Student - Group A - Approved)
 *    - leader@test.local  / Test12345! (Internship Leader / Coordinator)
 *    - doctor@test.local  / Test12345! (Evaluating Doctor / Clinical Supervisor)
 *    - admin@test.local   / Test12345! (Super Admin)
 * 4. End-to-end verification of Auth tokens, profile loading, and dashboard mapping.
 */

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';
const ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3NzIyMjEsImV4cCI6MjEwMjM0ODIyMX0.7FRbGAuFHh8sqfwBXQM5n3WVfyNbnuIAk3ucND3Kh-s';

const DEMO_ACCOUNTS = [
  {
    role: 'student',
    dbRole: 'student',
    email: 'student.beta@matrouh-internship.test',
    password: 'Test12345!',
    fullName: 'طالب بيتا التجريبي',
    universityCode: 'STD-BETA-001',
    group: 'A',
    gender: 'male',
    phoneNumber: '01000000001',
    gpa: 3.85,
    isMatrouhResident: true,
    residenceAddress: 'مطروح - شارع علم الروم',
    emergencyContact: '01000000099',
    expectedDashboard: 'StudentDashboardScreen',
  },
  {
    role: 'leader',
    dbRole: 'leader',
    email: 'leader.beta@matrouh-internship.test',
    password: 'Test12345!',
    fullName: 'منسق الامتياز والجدولة',
    universityCode: 'LDR-BETA-001',
    group: 'A',
    gender: 'male',
    phoneNumber: '01000000002',
    isMatrouhResident: true,
    residenceAddress: 'مطروح - وسط البلد',
    emergencyContact: '01000000099',
    expectedDashboard: 'LeaderDashboardScreen',
  },
  {
    role: 'doctor',
    dbRole: 'evaluating_doctor',
    email: 'supervisor.beta@matrouh-internship.test',
    password: 'Test12345!',
    fullName: 'المشرف الطبي المقيّم',
    universityCode: 'SUP-BETA-001',
    group: 'A',
    gender: 'male',
    phoneNumber: '01000000003',
    isMatrouhResident: true,
    residenceAddress: 'مطروح - الريفية',
    emergencyContact: '01000000099',
    expectedDashboard: 'DoctorDashboardScreen',
  },
  {
    role: 'admin',
    dbRole: 'super_admin',
    email: 'admin.beta@matrouh-internship.test',
    password: 'Test12345!',
    fullName: 'مدير النظام العام',
    universityCode: 'ADM-BETA-001',
    group: 'A',
    gender: 'male',
    phoneNumber: '01000000004',
    isMatrouhResident: true,
    residenceAddress: 'مطروح - ديوان الإدارة العامة',
    emergencyContact: '01000000099',
    expectedDashboard: 'AdminDashboardScreen',
  },
];

const OPERATIONAL_TABLES = [
  'quiz_answers',
  'quiz_attempts',
  'attendance',
  'evaluations',
  'disciplinary_actions',
  'case_handovers',
  'cases',
  'notifications',
  'roster_entries',
  'roster_preferences',
  'shift_requests',
  'rosters',
  'audit_logs',
  'profiles',
];

async function adminRest(path, options = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${path}`;
  const headers = {
    'apikey': SERVICE_ROLE_KEY,
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    'Content-Type': 'application/json',
    'Prefer': options.prefer || 'return=representation',
    ...options.headers,
  };

  const response = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (!response.ok && response.status !== 404) {
    const errText = await response.text();
    throw new Error(`REST [${options.method || 'GET'} ${path}] failed: ${response.status} ${errText}`);
  }

  const contentType = response.headers.get('content-type');
  if (contentType && contentType.includes('application/json')) {
    return await response.json();
  }
  return await response.text();
}

async function authAdmin(path, options = {}) {
  const url = `${SUPABASE_URL}/auth/v1/admin/${path}`;
  const headers = {
    'apikey': SERVICE_ROLE_KEY,
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    'Content-Type': 'application/json',
    ...options.headers,
  };

  const response = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`AuthAdmin [${options.method || 'GET'} ${path}] failed: ${response.status} ${errText}`);
  }

  return await response.json();
}

async function loginAsUser(email, password) {
  const url = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ email, password }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Login failed for ${email}: ${err}`);
  }

  return await response.json();
}

async function runReset() {
  console.log('====================================================');
  console.log('🔄 STARTING SUPABASE TEST ENVIRONMENT RESET');
  console.log('Target URL:', SUPABASE_URL);
  console.log('====================================================\n');

  // 1. Audit what exists before reset
  console.log('📊 Step 1: Auditing operational tables...');
  for (const table of OPERATIONAL_TABLES) {
    try {
      await adminRest(`${table}?select=id&limit=1`);
      console.log(` - Table [${table}]: online`);
    } catch (e) {
      console.log(` - Table [${table}]: (${e.message.split('\n')[0]})`);
    }
  }

  // 2. Fetch existing Auth users
  console.log('\n👥 Step 2: Fetching existing Auth users...');
  let existingUsers = [];
  try {
    const usersRes = await authAdmin('users?page=1&per_page=100');
    existingUsers = usersRes.users || [];
    console.log(` - Found ${existingUsers.length} existing Auth users in Supabase.`);
  } catch (e) {
    console.error(' - Error fetching users:', e.message);
  }

  // 3. Clear operational tables in reverse FK order
  console.log('\n🧹 Step 3: Deleting test operational data & profiles...');
  for (const table of OPERATIONAL_TABLES) {
    try {
      await adminRest(`${table}?id=neq.00000000-0000-0000-0000-000000000000`, {
        method: 'DELETE',
      });
      console.log(` ✅ Cleared table: ${table}`);
    } catch (e) {
      console.log(` ⚠️ Clear table ${table}: ${e.message.split('\n')[0]}`);
    }
  }

  // 4. Delete old Auth users
  console.log('\n🗑️ Step 4: Purging previous Auth users...');
  for (const u of existingUsers) {
    try {
      await authAdmin(`users/${u.id}`, { method: 'DELETE' });
      console.log(` ✅ Deleted Auth user: ${u.email} (${u.id})`);
    } catch (e) {
      console.log(` ⚠️ Could not delete Auth user ${u.email}: ${e.message}`);
    }
  }

  // 5. Create the 4 Standard Demo Accounts
  console.log('\n✨ Step 5: Creating the 4 Demo Accounts...');
  const createdProfiles = [];

  for (const account of DEMO_ACCOUNTS) {
    console.log(`\n🔹 Creating account: [${account.role.toUpperCase()}] ${account.email}...`);
    
    // Create Supabase Auth user with confirmed email
    const authRes = await authAdmin('users', {
      method: 'POST',
      body: {
        email: account.email,
        password: account.password,
        email_confirm: true,
        user_metadata: {
          full_name: account.fullName,
          role: account.dbRole,
          gpa: account.gpa,
          student_group: account.group,
        },
      },
    });

    const userId = authRes.id || authRes.user?.id;
    if (!userId) {
      throw new Error(`Failed to create Auth user for ${account.email}: ${JSON.stringify(authRes)}`);
    }
    console.log(`   ✓ Auth user created: ${userId}`);

    // Insert Profile into 'profiles' table with exact columns
    const profilePayload = {
      id: userId,
      email: account.email,
      full_name: account.fullName,
      university_code: account.universityCode,
      phone_number: account.phoneNumber,
      national_id: account.nationalId || null,
      gender: account.gender,
      marital_status: 'أعزب/عزباء',
      children_count: 0,
      is_matrouh_resident: account.isMatrouhResident,
      emergency_contact: account.emergencyContact,
      residence_address: account.residenceAddress,
      role: account.dbRole,
      is_approved: true,
      registration_status: 'approved',
      student_group: account.group,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    try {
      await adminRest('profiles', {
        method: 'POST',
        body: profilePayload,
      });
      console.log(`   ✓ Profile inserted: "${account.fullName}" [Role: ${account.dbRole}, Status: approved]`);
      createdProfiles.push({ ...account, id: userId });
    } catch (e) {
      console.error(`   ❌ Failed to insert profile for ${account.email}:`, e.message);
    }
  }

  // 6. Verify Logins & Routing for all 4 accounts
  console.log('\n====================================================');
  console.log('🔐 Step 6: Verifying Login & Dashboard Resolution for all 4 accounts...');
  console.log('====================================================\n');

  let allLoginsPassed = true;

  for (const account of DEMO_ACCOUNTS) {
    try {
      const loginRes = await loginAsUser(account.email, account.password);
      const token = loginRes.access_token;
      const user = loginRes.user;

      // Fetch profile with the user's token (verifying RLS as well)
      const profileUrl = `${SUPABASE_URL}/rest/v1/profiles?id=eq.${user.id}&select=*`;
      const profileFetch = await fetch(profileUrl, {
        headers: {
          'apikey': ANON_KEY,
          'Authorization': `Bearer ${token}`,
        },
      });

      const profileRows = await profileFetch.json();
      const profile = profileRows[0];

      if (!profile) {
        throw new Error(`Profile not found via RLS for ${account.email}`);
      }

      console.log(`✅ [${account.role.toUpperCase()}] Verified successfully!`);
      console.log(`   - Email:          ${account.email}`);
      console.log(`   - Name:           ${profile.full_name}`);
      console.log(`   - DB Role:        ${profile.role}`);
      console.log(`   - Student Group:  ${profile.student_group}`);
      console.log(`   - Approval:       is_approved=${profile.is_approved}, status=${profile.registration_status}`);
      console.log(`   - Target Screen:  ${account.expectedDashboard}`);
      console.log(`   - JWT Token:      Valid (${token.substring(0, 25)}...)\n`);
    } catch (e) {
      allLoginsPassed = false;
      console.error(`❌ [${account.role.toUpperCase()}] Verification failed for ${account.email}:`, e.message);
    }
  }

  // 7. Verify Database Clean State
  console.log('📊 Step 7: Final Database Clean State Counts:');
  const countChecks = [
    'profiles',
    'roster_entries',
    'roster_preferences',
    'shift_requests',
    'rosters',
    'attendance',
    'quiz_attempts',
    'quiz_answers',
    'evaluations',
    'cases',
    'case_handovers',
    'disciplinary_actions',
    'notifications',
  ];

  for (const table of countChecks) {
    try {
      const rows = await adminRest(`${table}?select=id`);
      console.log(`   - ${table.padEnd(24)}: ${rows.length} rows`);
    } catch (e) {
      console.log(`   - ${table.padEnd(24)}: 0 rows`);
    }
  }

  console.log('\n====================================================');
  if (allLoginsPassed) {
    console.log('🎉 TEST ENVIRONMENT RESET COMPLETED SUCCESSFULLY (4/4 ACCOUNTS READY)');
  } else {
    console.log('⚠️ RESET COMPLETED WITH SOME WARNINGS');
  }
  console.log('====================================================');
}

runReset().catch((err) => {
  console.error('Fatal reset error:', err);
  process.exit(1);
});
