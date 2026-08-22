const { adminRest, authAdmin, arabicFirstNamesMale, arabicFirstNamesFemale, arabicLastNames } = require('./qa_test_helpers');

async function getOrCreateAuthUser(email, password, metadata) {
  try {
    const created = await authAdmin('users', {
      method: 'POST',
      body: {
        email,
        password,
        email_confirm: true,
        user_metadata: metadata
      }
    });
    return created.id;
  } catch (err) {
    // If already exists, lookup user in auth
    const usersList = await authAdmin(`users?email=eq.${encodeURIComponent(email)}`);
    if (usersList && usersList.users && usersList.users.length > 0) {
      return usersList.users[0].id;
    }
    // Fallback: list all users or search
    const allUsers = await authAdmin('users?per_page=1000');
    const matched = (allUsers.users || []).find(u => u.email === email);
    if (matched) return matched.id;
    throw err;
  }
}

async function seedQaEnvironment() {
  console.log('====================================================');
  console.log('🚀 PHASE 2: PROVISIONING 145 QA TEST ACCOUNTS');
  console.log('====================================================\n');

  const depts = await adminRest('departments?select=id,name_ar');
  const deptIds = depts.map(d => d.id);

  const PASSWORD = 'QaTestPassword2026!';
  const usersCreated = [];

  // 1. Seed 5 Super Admins
  console.log('Creating 5 Test Super Admins...');
  for (let i = 1; i <= 5; i++) {
    const num = i.toString().padStart(2, '0');
    const email = `test.admin.${num}@matrouh-qa.test`;
    const fullName = `د. أدمن الفحص التجريبي ${num}`;

    const id = await getOrCreateAuthUser(email, PASSWORD, {
      full_name: fullName,
      role: 'super_admin',
      is_qa_test: true,
      fcm_token: `fcm_token_admin_${num}_test`
    });

    await adminRest('profiles', {
      method: 'POST',
      prefer: 'resolution=merge-duplicates,return=representation',
      body: {
        id,
        email,
        full_name: fullName,
        university_code: `ADM-${num}`,
        phone_number: `010100000${num}`,
        gender: 'male',
        role: 'super_admin',
        is_approved: true,
        registration_status: 'approved',
        is_matrouh_resident: true,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
    });
    usersCreated.push({ email, role: 'super_admin', id, fullName });
  }

  // 2. Seed 5 Leaders
  console.log('Creating 5 Test Leaders...');
  for (let i = 1; i <= 5; i++) {
    const num = i.toString().padStart(2, '0');
    const email = `test.leader.${num}@matrouh-qa.test`;
    const isMale = i % 2 !== 0;
    const first = isMale ? arabicFirstNamesMale[i % arabicFirstNamesMale.length] : arabicFirstNamesFemale[i % arabicFirstNamesFemale.length];
    const last = arabicLastNames[i % arabicLastNames.length];
    const fullName = `ليدر ${first} ${last}`;

    const id = await getOrCreateAuthUser(email, PASSWORD, {
      full_name: fullName,
      role: 'leader',
      is_qa_test: true,
      fcm_token: `fcm_token_leader_${num}_test`
    });

    await adminRest('profiles', {
      method: 'POST',
      prefer: 'resolution=merge-duplicates,return=representation',
      body: {
        id,
        email,
        full_name: fullName,
        university_code: `LDR-${num}`,
        phone_number: `010200000${num}`,
        gender: isMale ? 'male' : 'female',
        role: 'leader',
        is_approved: true,
        registration_status: 'approved',
        is_matrouh_resident: true,
        student_group: i % 2 === 0 ? 'B' : 'A',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
    });
    usersCreated.push({ email, role: 'leader', id, fullName });
  }

  // 3. Seed 5 Doctors
  console.log('Creating 5 Test Doctors...');
  for (let i = 1; i <= 5; i++) {
    const num = i.toString().padStart(2, '0');
    const email = `test.doctor.${num}@matrouh-qa.test`;
    const isMale = i % 2 !== 0;
    const first = isMale ? arabicFirstNamesMale[(i + 3) % arabicFirstNamesMale.length] : arabicFirstNamesFemale[(i + 3) % arabicFirstNamesFemale.length];
    const last = arabicLastNames[(i + 4) % arabicLastNames.length];
    const fullName = `د. ${first} ${last}`;

    const id = await getOrCreateAuthUser(email, PASSWORD, {
      full_name: fullName,
      role: 'evaluating_doctor',
      is_qa_test: true,
      fcm_token: `fcm_token_doctor_${num}_test`
    });

    await adminRest('profiles', {
      method: 'POST',
      prefer: 'resolution=merge-duplicates,return=representation',
      body: {
        id,
        email,
        full_name: fullName,
        university_code: `DOC-${num}`,
        phone_number: `010300000${num}`,
        gender: isMale ? 'male' : 'female',
        role: 'evaluating_doctor',
        is_approved: true,
        registration_status: 'approved',
        is_matrouh_resident: true,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
    });

    if (deptIds.length >= i) {
      const deptId = deptIds[i - 1];
      await adminRest('department_supervisors', {
        method: 'POST',
        prefer: 'resolution=merge-duplicates,return=representation',
        body: {
          department_id: deptId,
          doctor_id: id,
          male_capacity: 4,
          female_capacity: 7,
          assignment_status: 'approved',
          is_active: true,
          assigned_at: new Date().toISOString()
        }
      });
    }
    usersCreated.push({ email, role: 'evaluating_doctor', id, fullName });
  }

  // 4. Seed 130 Test Students
  console.log('Creating 130 Test Students with realistic distribution across departments & gender...');
  for (let i = 1; i <= 130; i++) {
    const num = i.toString().padStart(3, '0');
    const email = `test.student.${num}@matrouh-qa.test`;
    const isMale = (i % 5 === 1 || i % 5 === 3);
    const firstList = isMale ? arabicFirstNamesMale : arabicFirstNamesFemale;
    const first = firstList[i % firstList.length];
    const second = arabicFirstNamesMale[(i * 3) % arabicFirstNamesMale.length];
    const last = arabicLastNames[i % arabicLastNames.length];
    const fullName = `${first} ${second} ${last}`;
    const gpa = Number((2.80 + ((i % 120) * 0.01)).toFixed(2));
    const studentGroup = i % 2 === 0 ? 'B' : 'A';

    const id = await getOrCreateAuthUser(email, PASSWORD, {
      full_name: fullName,
      role: 'student',
      gpa,
      student_group: studentGroup,
      is_qa_test: true,
      fcm_token: i <= 50 ? `fcm_token_student_${num}_qa_test` : null
    });

    await adminRest('profiles', {
      method: 'POST',
      prefer: 'resolution=merge-duplicates,return=representation',
      body: {
        id,
        email,
        full_name: fullName,
        university_code: `STD-2026-${num}`,
        phone_number: `0104${num.padStart(7, '0')}`,
        national_id: null,
        gender: isMale ? 'male' : 'female',
        marital_status: i % 10 === 0 ? 'متزوج/متزوجة' : 'أعزب/عزباء',
        children_count: i % 10 === 0 ? 1 : 0,
        is_matrouh_resident: i % 4 !== 0,
        emergency_contact: `0109${num.padStart(7, '0')}`,
        residence_address: i % 2 === 0 ? 'مطروح - الكيلو 2' : 'مطروح - علم الروم',
        role: 'student',
        is_approved: true,
        registration_status: 'approved',
        student_group: studentGroup,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
    });

    usersCreated.push({ email, role: 'student', id, fullName, gender: isMale ? 'male' : 'female', gpa });
    if (i % 25 === 0) {
      console.log(`  ... Provisioned ${i}/130 students`);
    }
  }

  console.log(`\n✅ TEST ENVIRONMENT SEED COMPLETED:`);
  console.log(`- Super Admins: 5`);
  console.log(`- Leaders: 5`);
  console.log(`- Doctors: 5`);
  console.log(`- Students: 130 (Total Test Users: ${usersCreated.length})`);
  console.log('====================================================\n');

  return usersCreated;
}

if (require.main === module) {
  seedQaEnvironment().then(() => process.exit(0)).catch(err => {
    console.error('Seed Error:', err);
    process.exit(1);
  });
}

module.exports = { seedQaEnvironment };
