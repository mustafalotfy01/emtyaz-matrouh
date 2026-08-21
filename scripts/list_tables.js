const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';

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
