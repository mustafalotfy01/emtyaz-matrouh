const { userRest, authAdmin, SUPABASE_URL, ANON_KEY } = require('./qa_test_helpers.js');

async function testUser(email, roleName) {
  console.log(`\n=== Testing role: ${roleName} (${email}) ===`);
  const linkRes = await authAdmin('generate_link', {
    method: 'POST',
    body: {
      type: 'magiclink',
      email: email
    }
  });

  const hashed_token = linkRes.hashed_token || (linkRes.properties && linkRes.properties.hashed_token);
  if (!hashed_token) {
    console.log('Failed to extract token for', email, linkRes);
    return;
  }

  const verifyRes = await fetch(`${SUPABASE_URL}/auth/v1/verify`, {
    method: 'POST',
    headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      type: 'magiclink',
      token_hash: hashed_token
    })
  });

  const session = await verifyRes.json();
  if (!session.access_token) {
    console.log('Failed to get access token:', session);
    return;
  }

  const token = session.access_token;
  console.log('Logged in User ID:', session.user.id);

  // Test 1: SELECT from disciplinary_actions
  const selRes = await userRest(token, 'disciplinary_actions?select=*,student:student_id(id,full_name,university_code),creator:created_by(id,full_name),approver:approved_by(id,full_name),department:department_id(id,name_ar)');
  console.log('SELECT status:', selRes.status, 'Items count:', Array.isArray(selRes.data) ? selRes.data.length : 'ERROR: ' + JSON.stringify(selRes.data));
  if (Array.isArray(selRes.data)) {
    console.log('Items found:', JSON.stringify(selRes.data, null, 2));
  }
}

async function main() {
  await testUser('mostafagraphix@gmail.com', 'student');
}
main();
