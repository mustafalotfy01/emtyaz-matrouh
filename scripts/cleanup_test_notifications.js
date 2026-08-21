const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function cleanupTestNotifications() {
  console.log('=== Cleaning Up Test Runner Notifications ===');
  
  // Find test-specific titles
  const testTitles = [
    'تحديث الروستر من القائد',
    'إشعار مباشر',
    'تنبيه نوبتجيات قسم الطوارئ 🏥',
    'تنبيه للمجموعة A',
    'تنبيه إداري عام لجميع الطلاب'
  ];

  for (const title of testTitles) {
    const delRes = await fetch(`${SUPABASE_URL}/rest/v1/notifications?title=eq.${encodeURIComponent(title)}`, {
      method: 'DELETE',
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: 'Bearer ' + SERVICE_ROLE_KEY,
        Prefer: 'return=representation'
      }
    });
    const deleted = await delRes.json();
    console.log(`Deleted ${deleted.length || 0} records for title: "${title}"`);
  }

  // Inspect remaining notifications
  const res = await fetch(SUPABASE_URL + '/rest/v1/notifications?select=*&order=created_at.desc', {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  const remaining = await res.json();
  console.log('\nRemaining Real Notifications in DB:', remaining.length);
  remaining.forEach((n, idx) => {
    console.log(`[${idx + 1}] ID: ${n.id} | User: ${n.user_id} | Title: "${n.title}" | Type: ${n.type} | Created: ${n.created_at}`);
  });
}

cleanupTestNotifications();
