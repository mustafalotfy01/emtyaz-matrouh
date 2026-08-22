const SUPABASE_URL = 'https://zlxumwvygqcxhareknul.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Njc3MjIyMSwiZXhwIjoyMTAyMzQ4MjIxfQ.kzcY871QMGYOKFougygGtHZnopmzkAxZWJlFtGxNC7E';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseHVtd3Z5Z3FjeGhhcmVrbnVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3NzIyMjEsImV4cCI6MjEwMjM0ODIyMX0.7FRbGAuFHh8sqfwBXQM5n3WVfyNbnuIAk3ucND3Kh-s';

const arabicFirstNamesMale = ['أحمد', 'محمد', 'محمود', 'عمر', 'علي', 'يوسف', 'إبراهيم', 'خالد', 'مصطفى', 'كريم', 'طارق', 'زياد', 'حسن', 'حسين', 'سيف', 'حمزة'];
const arabicFirstNamesFemale = ['سارة', 'فاطمة', 'مريم', 'نور', 'ياسمين', 'آية', 'دعاء', 'هدى', 'رنا', 'سلمى', 'دينا', 'إيمان', 'منة', 'شروق', 'حبيبة', 'مروة'];
const arabicLastNames = ['الشافعي', 'المصري', 'النجار', 'السيد', 'عبدالرحمن', 'المنشاوي', 'إبراهيم', 'بدوي', 'الحداد', 'العربي', 'سليمان', 'عثمان', 'رضا', 'فهمي', 'غريب'];

async function adminRest(path, options = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${path}`;
  const headers = {
    'apikey': SERVICE_ROLE_KEY,
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    'Content-Type': 'application/json',
    'Prefer': options.prefer || 'return=representation',
    ...(options.headers || {})
  };
  const res = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  if (!res.ok && res.status !== 404) {
    const errText = await res.text();
    throw new Error(`REST [${options.method || 'GET'} ${path}] failed (${res.status}): ${errText}`);
  }
  const ct = res.headers.get('content-type');
  if (ct && ct.includes('application/json')) return await res.json();
  return await res.text();
}

async function userRest(token, path, options = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${path}`;
  const headers = {
    'apikey': ANON_KEY,
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'Prefer': options.prefer || 'return=representation',
    ...(options.headers || {})
  };
  const res = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  const ct = res.headers.get('content-type');
  const body = ct && ct.includes('application/json') ? await res.json() : await res.text();
  return { status: res.status, ok: res.ok, data: body };
}

async function authAdmin(path, options = {}) {
  const url = `${SUPABASE_URL}/auth/v1/admin/${path}`;
  const headers = {
    'apikey': SERVICE_ROLE_KEY,
    'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
    'Content-Type': 'application/json',
    ...(options.headers || {})
  };
  const res = await fetch(url, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`AuthAdmin [${options.method || 'GET'} ${path}] failed (${res.status}): ${errText}`);
  }
  return await res.json();
}

async function userSignIn(email, password) {
  const url = `${SUPABASE_URL}/auth/v1/token?grant_type=password`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`SignIn failed (${res.status}): ${errText}`);
  }
  return await res.json();
}

module.exports = {
  SUPABASE_URL,
  SERVICE_ROLE_KEY,
  ANON_KEY,
  adminRest,
  userRest,
  authAdmin,
  userSignIn,
  arabicFirstNamesMale,
  arabicFirstNamesFemale,
  arabicLastNames
};
