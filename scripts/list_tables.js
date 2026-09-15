const SUPABASE_URL = process.env.SUPABASE_URL || 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

async function listTables() {
  const tables = [
    'profiles', 'notifications', 'departments', 'student_roster_preferences', 
    'rosters', 'roster_assignments', 'roster_months', 'attendance_records',
    'evaluation_records', 'user_push_tokens', 'push_tokens', 'fcm_tokens', 'device_tokens'
  ];

  for (const t of tables) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/${t}?limit=1`, {
      headers: { apikey: SERVICE_ROLE_KEY, Authorization: 'Bearer ' + SERVICE_ROLE_KEY }
    });
    console.log(`Table '${t}': HTTP ${res.status}`);
  }
}

listTables();
