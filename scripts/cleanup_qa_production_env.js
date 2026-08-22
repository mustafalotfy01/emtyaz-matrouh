const { adminRest, authAdmin } = require('./qa_test_helpers');

async function cleanupQaEnvironment() {
  console.log('====================================================');
  console.log('🧹 CLEANING UP QA TEST ENVIRONMENT');
  console.log('====================================================\n');

  // Find all profiles ending with @matrouh-qa.test
  const testProfiles = await adminRest('profiles?email=like.*%40matrouh-qa.test');
  console.log(`Found ${testProfiles.length} QA test profiles to clean up.`);

  for (const prof of testProfiles) {
    const id = prof.id;
    try {
      await adminRest(`notifications?user_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`attendance?student_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`roster_entries?student_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`roster_preferences?student_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`evaluations?student_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`cases?student_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`case_handovers?from_student_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`case_handovers?to_student_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`disciplinary_actions?student_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`confirmation_requests?target_student_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`department_supervisors?doctor_id=eq.${id}`, { method: 'DELETE' });
      await adminRest(`profiles?id=eq.${id}`, { method: 'DELETE' });
      await authAdmin(`users/${id}`, { method: 'DELETE' });
    } catch (_) {}
  }

  // Also clean up any test rosters or test campaigns created during QA
  try {
    await adminRest('roster_preferences?roster_id=like.*2026-qa*', { method: 'DELETE' });
    await adminRest('roster_entries?roster_id=like.*2026-qa*', { method: 'DELETE' });
    await adminRest('rosters?id=like.*2026-qa*', { method: 'DELETE' });
  } catch (_) {}

  console.log('✅ QA Clean up finished successfully.\n');
}

if (require.main === module) {
  cleanupQaEnvironment().then(() => process.exit(0)).catch(console.error);
}

module.exports = { cleanupQaEnvironment };
