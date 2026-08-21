const fs = require('fs');
const log = 'C:/Users/FUJITSU/.gemini/antigravity/brain/dc03c6e2-7da9-407e-a932-54164cade876/.system_generated/logs/transcript.jsonl';
if (fs.existsSync(log)) {
  const lines = fs.readFileSync(log, 'utf8').split('\n');
  for (const line of lines) {
    if (line.includes('Emtaz-Matrouh') || line.includes('firebase') || line.includes('vapid') || line.includes('messagingSenderId')) {
      console.log('Firebase Match:', line.substring(0, 300));
    }
  }
}
