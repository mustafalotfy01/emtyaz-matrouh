const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function auditTables() {
  console.log('=== Checking Supabase Tables & Schema ===');

  // 1. notifications table
  const nRes = await fetch(SUPABASE_URL + '/rest/v1/notifications?limit=1', {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  console.log('notifications table status:', nRes.status);
  const nData = await nRes.json();
  console.log('notifications sample row keys:', nData[0] ? Object.keys(nData[0]) : 'empty table');

  // 2. notification_campaigns table
  const cRes = await fetch(SUPABASE_URL + '/rest/v1/notification_campaigns?limit=1', {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  console.log('notification_campaigns table status:', cRes.status);
  const cData = await cRes.json();
  console.log('notification_campaigns response:', cData);

  // 3. push_subscriptions table
  const pRes = await fetch(SUPABASE_URL + '/rest/v1/push_subscriptions?limit=5', {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  console.log('push_subscriptions table status:', pRes.status);
  const pData = await pRes.json();
  console.log('push_subscriptions count:', pData.length || 0);
  console.log('push_subscriptions rows:', pData);

  // 4. Test insert into notifications with metadata
  console.log('\nTesting insert into notifications with metadata column...');
  const testInsert = await fetch(SUPABASE_URL + '/rest/v1/notifications', {
    method: 'POST',
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: 'Bearer ' + SERVICE_ROLE_KEY,
      'Content-Type': 'application/json',
      Prefer: 'return=representation'
    },
    body: JSON.stringify({
      user_id: 'cfa3f63b-0d77-408c-a8fd-69d3c453ceef',
      title: 'TEST_AUDIT_INSERT',
      message: 'testing metadata support',
      type: 'GENERAL',
      metadata: { test: true },
      is_read: false
    })
  });
  console.log('Test insert status:', testInsert.status);
  const testData = await testInsert.json();
  console.log('Test insert result:', testData);

  // Delete test insert
  if (testData[0]?.id) {
    await fetch(SUPABASE_URL + `/rest/v1/notifications?id=eq.${testData[0].id}`, {
      method: 'DELETE',
      headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
    });
    console.log('Cleaned up test row.');
  }
}

auditTables();
