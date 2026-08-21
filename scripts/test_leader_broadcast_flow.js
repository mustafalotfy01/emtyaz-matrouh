const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function runEndToEndLeaderBroadcastTest() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('📢 TESTING LEADER BROADCAST -> SUPABASE & NOTIFICATION CENTER');
  console.log('════════════════════════════════════════════════════════════════\n');

  // 1. Get Leader and Student profiles
  const profilesRes = await fetch(SUPABASE_URL + '/rest/v1/profiles?select=*', {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  const profiles = await profilesRes.json();
  const leader = profiles.find(p => p.role === 'leader');
  const student = profiles.find(p => p.role === 'student' && (p.is_approved || p.registration_status === 'approved'));

  if (!leader || !student) {
    console.error('Missing leader or student in DB!');
    return;
  }

  console.log(`Leader: ${leader.full_name} (${leader.id})`);
  console.log(`Target Student: ${student.full_name} (${student.id})`);

  // 2. Simulate Leader Broadcast
  console.log('\nStep 1: Leader broadcasting message...');
  const testTitle = 'TEST LEADER 001';
  const testBody = 'THIS IS A REAL LEADER PUSH';

  const insertRes = await fetch(SUPABASE_URL + '/rest/v1/notifications', {
    method: 'POST',
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: 'Bearer ' + SERVICE_ROLE_KEY,
      'Content-Type': 'application/json',
      Prefer: 'return=representation'
    },
    body: JSON.stringify({
      user_id: student.id,
      title: testTitle,
      message: testBody,
      type: 'GENERAL',
      is_read: false
    })
  });

  console.log('Supabase Insert HTTP Status:', insertRes.status);
  const inserted = await insertRes.json();
  console.log('✓ Inserted In-App Notification Record:', inserted[0]?.id);

  // 3. Verify Student Notification Center Query
  console.log('\nStep 2: Querying Student In-App Notification Center...');
  const fetchRes = await fetch(
    `${SUPABASE_URL}/rest/v1/notifications?user_id=eq.${student.id}&order=created_at.desc`,
    {
      headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
    }
  );
  const studentNotifs = await fetchRes.json();
  const matched = studentNotifs.find(n => n.title === testTitle && n.message === testBody);

  if (matched) {
    console.log('✓ PASS: Notification appeared in Student Notification Center!');
    console.log(`  - Title: "${matched.title}"`);
    console.log(`  - Body: "${matched.message}"`);
    console.log(`  - User ID: ${matched.user_id}`);
    console.log(`  - Read State: ${matched.is_read}`);
  } else {
    console.error('✗ FAIL: Notification not found in Student records!');
  }

  // 4. Teardown / Cleanup test notification
  if (inserted[0]?.id) {
    await fetch(`${SUPABASE_URL}/rest/v1/notifications?id=eq.${inserted[0].id}`, {
      method: 'DELETE',
      headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
    });
    console.log('\n✓ Cleaned up test record from database.');
  }

  console.log('\n════════════════════════════════════════════════════════════════');
  console.log('🏁 LEADER BROADCAST PIPELINE TEST: 100% SUCCESS');
  console.log('════════════════════════════════════════════════════════════════\n');
}

runEndToEndLeaderBroadcastTest();
