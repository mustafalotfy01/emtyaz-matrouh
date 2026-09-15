const https = require('https');

const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3NzIyMjEsImV4cCI6MjEwMjM0ODIyMX0.7FRbGAuFHh8sqfwBXQM5n3WVfyNbnuIAk3ucND3Kh-s';

function apiRequest(path, method = 'GET', body = null, token = ANON_KEY) {
  return new Promise((resolve) => {
    const dataStr = body ? (typeof body === 'string' ? body : JSON.stringify(body)) : null;
    const req = https.request({
      hostname: 'zlxumwvygqcxhareknul.supabase.co',
      path,
      method,
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
        ...(dataStr ? { 'Content-Length': Buffer.byteLength(dataStr) } : {})
      }
    }, res => {
      let responseBody = '';
      res.on('data', chunk => responseBody += chunk);
      res.on('end', () => {
        let parsed;
        try {
          parsed = JSON.parse(responseBody);
        } catch {
          parsed = responseBody;
        }
        resolve({ status: res.statusCode, data: parsed, raw: responseBody });
      });
    });

    req.on('error', (err) => resolve({ status: 500, error: err.message }));
    if (dataStr) req.write(dataStr);
    req.end();
  });
}

async function runProductionTests() {
  console.log('====================================================');
  console.log('  ITEM 10 — PRODUCTION VERIFICATION ATTACK SUITE');
  console.log('====================================================\n');

  // TEST A: Anonymous request to broadcast-notification Edge Function
  console.log('--- TEST A: Anonymous request to broadcast-notification Edge Function ---');
  const resA = await apiRequest('/functions/v1/broadcast-notification', 'POST', {
    audience_type: 'ALL_STUDENTS',
    title: 'Hacked Broadcast',
    body: 'Spam from unauthenticated attacker'
  }, ''); // empty token
  console.log('Status:', resA.status, '| Output:', JSON.stringify(resA.data));
  const passA = resA.status === 401;
  console.log('Result:', passA ? 'PASS (401 Unauthorized)' : 'FAIL');

  // TEST B: Invalid / Forged JWT request to broadcast-notification Edge Function
  console.log('\n--- TEST B: Forged JWT to broadcast-notification Edge Function ---');
  const resB = await apiRequest('/functions/v1/broadcast-notification', 'POST', {
    audience_type: 'ALL_STUDENTS',
    title: 'Forged Broadcast',
    body: 'Spam using fake JWT'
  }, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake.signature');
  console.log('Status:', resB.status, '| Output:', JSON.stringify(resB.data));
  const passB = resB.status === 401;
  console.log('Result:', passB ? 'PASS (401 Unauthorized)' : 'FAIL');

  // TEST C: Anonymous execution of send_broadcast_notification_rpc
  console.log('\n--- TEST C: Anonymous invocation of send_broadcast_notification_rpc ---');
  const resC = await apiRequest('/rest/v1/rpc/send_broadcast_notification_rpc', 'POST', {
    p_audience_type: 'ALL_STUDENTS',
    p_title: 'Unauthenticated RPC',
    p_body: 'Attempt to bypass Edge Function'
  });
  console.log('Status:', resC.status, '| Output:', JSON.stringify(resC.data));
  const passC = resC.status === 400 && String(resC.raw).includes('Unauthorized');
  console.log('Result:', passC ? 'PASS (Rejected: Caller authentication required)' : 'FAIL');

  // TEST D: Rate limiter unauthenticated execution
  console.log('\n--- TEST D: Rate limiter with null user_id ---');
  const resD = await apiRequest('/rest/v1/rpc/check_and_record_rate_limit', 'POST', {
    p_user_id: null,
    p_action_type: 'TEST_ACTION',
    p_max_requests: 5,
    p_window_seconds: 60,
    p_cooldown_seconds: 15
  });
  console.log('Status:', resD.status, '| Output:', JSON.stringify(resD.data));
  const passD = resD.status === 200 && resD.data?.allowed === false && resD.data?.reason === 'UNAUTHENTICATED';
  console.log('Result:', passD ? 'PASS (Blocked with UNAUTHENTICATED)' : 'FAIL');

  // TEST E: Direct anonymous INSERT into notifications table
  console.log('\n--- TEST E: Direct anonymous INSERT into public.notifications ---');
  const resE = await apiRequest('/rest/v1/notifications', 'POST', {
    title: 'Direct Table Spam',
    message: 'Attempting to inject row directly',
    type: 'SPAM'
  });
  console.log('Status:', resE.status, '| Output:', JSON.stringify(resE.data));
  const passE = (resE.status === 401 || resE.status === 403) && String(resE.raw).includes('violates row-level security policy');
  console.log('Result:', passE ? 'PASS (401/42501 RLS Policy Violation)' : 'FAIL');

  // TEST F: Direct anonymous SELECT on notifications table
  console.log('\n--- TEST F: Direct anonymous SELECT on public.notifications ---');
  const resF = await apiRequest('/rest/v1/notifications?limit=5');
  console.log('Status:', resF.status, '| Output:', JSON.stringify(resF.data));
  const passF = resF.status === 200 && Array.isArray(resF.data) && resF.data.length === 0;
  console.log('Result:', passF ? 'PASS (Empty array returned, RLS isolated)' : 'FAIL');

  // TEST G: Direct anonymous INSERT into push_subscriptions table
  console.log('\n--- TEST G: Direct anonymous INSERT into public.push_subscriptions ---');
  const resG = await apiRequest('/rest/v1/push_subscriptions', 'POST', {
    endpoint: 'fcm:fake_token_attempt',
    platform: 'web'
  });
  console.log('Status:', resG.status, '| Output:', JSON.stringify(resG.data));
  const passG = (resG.status === 401 || resG.status === 403) && String(resG.raw).includes('violates row-level security policy');
  console.log('Result:', passG ? 'PASS (401/42501 RLS Policy Violation)' : 'FAIL');

  // TEST H: Direct anonymous SELECT on push_subscriptions table
  console.log('\n--- TEST H: Direct anonymous SELECT on public.push_subscriptions ---');
  const resH = await apiRequest('/rest/v1/push_subscriptions?limit=5');
  console.log('Status:', resH.status, '| Output:', JSON.stringify(resH.data));
  const passH = resH.status === 200 && Array.isArray(resH.data) && resH.data.length === 0;
  console.log('Result:', passH ? 'PASS (Empty array returned, tokens isolated)' : 'FAIL');

  // TEST I: Direct anonymous SELECT on security_rate_limits table
  console.log('\n--- TEST I: Direct anonymous SELECT on public.security_rate_limits ---');
  const resI = await apiRequest('/rest/v1/security_rate_limits?limit=5');
  console.log('Status:', resI.status, '| Output:', JSON.stringify(resI.data));
  const passI = resI.status === 200 && Array.isArray(resI.data) && resI.data.length === 0;
  console.log('Result:', passI ? 'PASS (Empty array returned, rate limits isolated)' : 'FAIL');

  // TEST J: Direct anonymous INSERT into security_rate_limits table
  console.log('\n--- TEST J: Direct anonymous INSERT into public.security_rate_limits ---');
  const resJ = await apiRequest('/rest/v1/security_rate_limits', 'POST', {
    action_type: 'FORGED_LIMIT',
    request_count: 999
  });
  console.log('Status:', resJ.status, '| Output:', JSON.stringify(resJ.data));
  const passJ = (resJ.status === 401 || resJ.status === 403) && String(resJ.raw).includes('violates row-level security policy');
  console.log('Result:', passJ ? 'PASS (401/42501 RLS Policy Violation)' : 'FAIL');

  // TEST K: Direct anonymous SELECT on notification_campaigns table
  console.log('\n--- TEST K: Direct anonymous SELECT on public.notification_campaigns ---');
  const resK = await apiRequest('/rest/v1/notification_campaigns?limit=5');
  console.log('Status:', resK.status, '| Output:', JSON.stringify(resK.data));
  const passK = resK.status === 200 && Array.isArray(resK.data) && resK.data.length === 0;
  console.log('Result:', passK ? 'PASS (Empty array returned, campaigns isolated)' : 'FAIL');

  console.log('\n====================================================');
  console.log('  SUMMARY OF PRODUCTION ATTACK TESTS');
  console.log('====================================================');
  console.log(`TEST A (Edge Function Anon):          ${passA ? 'PASS' : 'FAIL'}`);
  console.log(`TEST B (Edge Function Forged JWT):    ${passB ? 'PASS' : 'FAIL'}`);
  console.log(`TEST C (Broadcast RPC Anon):          ${passC ? 'PASS' : 'FAIL'}`);
  console.log(`TEST D (Rate Limit Null User):        ${passD ? 'PASS' : 'FAIL'}`);
  console.log(`TEST E (Notifications Insert Anon):   ${passE ? 'PASS' : 'FAIL'}`);
  console.log(`TEST F (Notifications Select Anon):   ${passF ? 'PASS' : 'FAIL'}`);
  console.log(`TEST G (Push Subs Insert Anon):       ${passG ? 'PASS' : 'FAIL'}`);
  console.log(`TEST H (Push Subs Select Anon):       ${passH ? 'PASS' : 'FAIL'}`);
  console.log(`TEST I (Rate Limits Select Anon):     ${passI ? 'PASS' : 'FAIL'}`);
  console.log(`TEST J (Rate Limits Insert Anon):     ${passJ ? 'PASS' : 'FAIL'}`);
  console.log(`TEST K (Campaigns Select Anon):       ${passK ? 'PASS' : 'FAIL'}`);

  const allPassed = passA && passB && passC && passD && passE && passF && passG && passH && passI && passJ && passK;
  console.log(`\nOVERALL PRODUCTION VERIFICATION RESULT: ${allPassed ? 'ALL TESTS PASSED' : 'SOME TESTS FAILED'}`);
}

runProductionTests();
