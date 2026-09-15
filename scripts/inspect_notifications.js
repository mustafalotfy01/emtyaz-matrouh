const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

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
