const fs = require('fs');
const log = 'C:/Users/FUJITSU/.gemini/antigravity/brain/dc03c6e2-7da9-407e-a932-54164cade876/.system_generated/logs/transcript.jsonl';
if (fs.existsSync(log)) {
  const lines = fs.readFileSync(log, 'utf8').split('\n');
  for (const line of lines) {
    if (line.includes('postgresql://') || line.includes('postgres://') || line.includes('DATABASE_URL') || line.includes('PGPASSWORD')) {
      console.log('Match:', line.substring(0, 300));
      break;
    }
  }
}
