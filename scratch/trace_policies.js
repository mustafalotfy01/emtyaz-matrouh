const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'supabase', 'migrations');
const files = fs.readdirSync(dir).filter(f => f.endsWith('.sql')).sort();

const policies = {}; // table -> { policyName -> { full, file, line } }

for (const file of files) {
  const content = fs.readFileSync(path.join(dir, file), 'utf8');
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const dropMatch = line.match(/DROP\s+POLICY\s+(?:IF\s+EXISTS\s+)?["']?([^"'\s]+)["']?\s+ON\s+public\.([a-zA-Z0-9_]+)/i);
    if (dropMatch) {
      const pol = dropMatch[1];
      const tbl = dropMatch[2];
      if (policies[tbl] && policies[tbl][pol]) {
        delete policies[tbl][pol];
      }
    }
    const createMatch = line.match(/CREATE\s+POLICY\s+["']?([^"'\s]+)["']?\s+ON\s+public\.([a-zA-Z0-9_]+)/i);
    if (createMatch) {
      const pol = createMatch[1];
      const tbl = createMatch[2];
      if (!policies[tbl]) policies[tbl] = {};
      let full = '';
      let j = i;
      while (j < lines.length) {
        full += ' ' + lines[j].trim();
        if (lines[j].includes(';')) break;
        j++;
      }
      policies[tbl][pol] = { full: full.trim(), file, line: i + 1 };
    }
  }
}

const targetTables = [
  'profiles',
  'roster_entries',
  'attendance',
  'evaluations',
  'disciplinary_actions',
  'cases',
  'notifications',
  'community_posts',
  'community_comments',
  'confirmation_requests',
  'quizzes',
  'quiz_questions',
  'quiz_options',
  'quiz_attempts',
  'quiz_answers',
  'roster_preferences',
  'shift_requests',
  'case_handovers',
  'department_supervisors',
  'departments'
];

let out = '';
for (const tbl of targetTables) {
  out += `\n========================================\n`;
  out += `TABLE: public.${tbl}\n`;
  out += `========================================\n`;
  const pols = policies[tbl] || {};
  const names = Object.keys(pols);
  if (names.length === 0) {
    out += '  (NO POLICIES DEFINED OR ALL DROPPED)\n';
  }
  for (const name of names) {
    out += `  POLICY "${name}" [${pols[name].file}:${pols[name].line}]:\n`;
    out += `    ${pols[name].full}\n`;
  }
}

fs.writeFileSync(path.join(__dirname, 'effective_policies.txt'), out, 'utf8');
console.log('Written to scratch/effective_policies.txt');
