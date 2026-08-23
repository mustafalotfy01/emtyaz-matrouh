const { adminRest, userRest, authAdmin, SUPABASE_URL, ANON_KEY } = require('./qa_test_helpers.js');

async function testFingerprint(email) {
  console.log('Testing fingerprint request from:', email);
  const linkRes = await authAdmin('generate_link', {
    method: 'POST',
    body: { type: 'magiclink', email: email }
  });
  const hashed_token = linkRes.hashed_token || (linkRes.properties && linkRes.properties.hashed_token);
  const verifyRes = await fetch(`${SUPABASE_URL}/auth/v1/verify`, {
    method: 'POST',
    headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ type: 'magiclink', token_hash: hashed_token })
  });
  const session = await verifyRes.json();
  const token = session.access_token;
  console.log('Logged in ID:', session.user.id);
  
  const now = new Date().toISOString();
  const insRes = await userRest(token, 'confirmation_requests', {
    method: 'POST',
    body: {
      sender_id: session.user.id,
      audience_type: 'SPECIFIC_STUDENT',
      target_student_id: 'd0d7c3b7-ad56-4ae0-b7c6-04fcfcb205a1',
      title: 'طلب بصمة للطالب مصطفي محمود لطفي',
      notes: null,
      status: 'pending',
      sent_at: now,
      created_at: now,
      updated_at: now
    }
  });
  console.log('Insert status:', insRes.status, 'Response:', JSON.stringify(insRes.data, null, 2));

  // Also check column schema of confirmation_requests
  const allReqs = await adminRest('confirmation_requests?select=*&limit=3');
  console.log('Sample rows from confirmation_requests:', JSON.stringify(allReqs, null, 2));
}

async function main() {
  await testFingerprint('mostafa.lotfy@matrouh-nursing.edu.eg');
}
main();
