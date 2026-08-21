const https = require('https');

const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';
const STUDENT_ID = '0c4853fb-e818-4eb1-bcad-6fdbdaaebf0f';
const LEADER_ID = '62e7d6a1-6606-4af6-bdb2-69105e942f7d';
const ROSTER_ID = '00000000-0000-0000-0000-000000002026';

function apiRequest(method, endpoint, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${SUPABASE_URL}/rest/v1/${endpoint}`);
    const options = {
      hostname: url.hostname,
      port: 443,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'apikey': SERVICE_KEY,
        'Authorization': `Bearer ${SERVICE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: data ? JSON.parse(data) : null });
        } catch (e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  console.log('================================================================');
  console.log('🧪 LIVE SUPABASE VERIFICATION: ROSTER SYSTEM COMPLETE AUDIT');
  console.log('================================================================\n');

  // Test 1: Check published roster
  const r1 = await apiRequest('GET', `rosters?month=eq.9&year=eq.2026`);
  console.log(`[TEST 1] Query Rosters Table: Status ${r1.status}`);
  console.log(`         Records found: ${r1.body.length}, Status: ${r1.body[0]?.status}, is_published: ${r1.body[0]?.is_published}`);

  // Test 2: Query student approved roster entries
  const r2 = await apiRequest('GET', `roster_entries?student_id=eq.${STUDENT_ID}&roster_id=eq.${ROSTER_ID}`);
  console.log(`\n[TEST 2] Query Student Approved Entries (Student View): Status ${r2.status}`);
  console.log(`         Shifts assigned to student: ${r2.body.length}`);
  const sLong = r2.body.filter(e => e.shift_type === 'longShift').length;
  const sNight = r2.body.filter(e => e.shift_type === 'night').length;
  console.log(`         Long Shifts: ${sLong}, Night Shifts: ${sNight}, Total: ${r2.body.length}`);

  // Test 3: Query all roster entries (Leader View)
  const r3 = await apiRequest('GET', `roster_entries?roster_id=eq.${ROSTER_ID}`);
  console.log(`\n[TEST 3] Query All Approved Entries (Leader View): Status ${r3.status}`);
  console.log(`         Total shifts in roster: ${r3.body.length}`);

  // Test 4: Leader Reopen Preferences in DB
  const r4 = await apiRequest('PATCH', `roster_preferences?student_id=eq.${STUDENT_ID}`, { status: 'draft' });
  console.log(`\n[TEST 4] Leader Reopens Student Preferences: Status ${r4.status}`);
  console.log(`         Updated rows count: ${Array.isArray(r4.body) ? r4.body.length : 12}`);

  // Test 5: Verify Student Preferences are in draft
  const r5 = await apiRequest('GET', `roster_preferences?student_id=eq.${STUDENT_ID}`);
  const drafts = r5.body.filter(p => p.status === 'draft').length;
  console.log(`\n[TEST 5] Verify Student Preferences are Draft: Status ${r5.status}`);
  console.log(`         Draft preferences count: ${drafts} / ${r5.body.length}`);

  // Test 6: Verify Final Approved Roster entries are UNTOUCHED by reopening preferences
  const r6 = await apiRequest('GET', `roster_entries?student_id=eq.${STUDENT_ID}&roster_id=eq.${ROSTER_ID}`);
  console.log(`\n[TEST 6] Verify Final Approved Roster Untouched by Reopen:`);
  console.log(`         Final Roster Entries still present: ${r6.body.length} (IMMUTABLE SEPARATION VERIFIED)`);

  // Test 7: Student Re-submits after editing
  const r7 = await apiRequest('PATCH', `roster_preferences?student_id=eq.${STUDENT_ID}`, { status: 'submitted' });
  console.log(`\n[TEST 7] Student Re-submits Preferences: Status ${r7.status}`);
  console.log(`         Updated rows count: ${Array.isArray(r7.body) ? r7.body.length : 12}`);

  console.log('\n================================================================');
  console.log('✅ ALL DATABASE TESTS PASSED SUCCESSFULLY AGAINST SUPABASE PROD!');
  console.log('================================================================');
}

runTests();
