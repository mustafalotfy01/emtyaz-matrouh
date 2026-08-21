const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

async function listAll() {
  const res = await fetch(SUPABASE_URL + '/rest/v1/notifications?select=*&order=created_at.desc', {
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
  });
  const data = await res.json();
  console.log('Total notifications in DB:', data.length);
  data.forEach((n, idx) => {
    console.log(`[${idx + 1}] ID: ${n.id} | User: ${n.user_id} | Title: "${n.title}" | Type: ${n.type} | Created: ${n.created_at}`);
  });
}

listAll();
