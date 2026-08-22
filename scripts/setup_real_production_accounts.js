const { SUPABASE_URL, SERVICE_ROLE_KEY, adminRest, authAdmin } = require('./qa_test_helpers');

const DEFAULT_PASSWORD = 'Matrouh@2026!';

const ACCOUNTS = [
  // --- ADMNS (الإدارة العليا والمنسقين) ---
  {
    fullName: 'أ.م.د. ميسة البياع',
    email: 'dr.maysa.elbayaa@matrouh-nursing.edu.eg',
    role: 'super_admin',
    jobTitle: 'المنسق الأكاديمي لسنة الامتياز',
    gender: 'female',
    category: 'admin'
  },
  {
    fullName: 'أ.د. أمل عبدالرازق',
    email: 'dr.amal.abdelrazek@matrouh-nursing.edu.eg',
    role: 'super_admin',
    jobTitle: 'عميد كلية التمريض - جامعة مطروح',
    gender: 'female',
    category: 'admin'
  },
  {
    fullName: 'أ.د. نانسي الساخي',
    email: 'dr.nancy.elsakhy@matrouh-nursing.edu.eg',
    role: 'super_admin',
    jobTitle: 'وكيل الكلية / إدارة الامتياز',
    gender: 'female',
    category: 'admin'
  },
  {
    fullName: 'د. أمنية محمد',
    email: 'dr.omnia.mohamed@matrouh-nursing.edu.eg',
    role: 'super_admin',
    jobTitle: 'المشرف العام ومسئول سنة الامتياز',
    gender: 'female',
    category: 'admin_and_doctor',
    deptNames: ['قسم الطوارئ', 'عناية باطنة']
  },

  // --- EVALUATING DOCTORS (الدكاترة المقييمين) ---
  {
    fullName: 'د. شيرين فرج',
    email: 'dr.shereen.farag@matrouh-nursing.edu.eg',
    role: 'evaluating_doctor',
    jobTitle: 'مسئول أريا الحضانة (NICU)',
    gender: 'female',
    category: 'doctor',
    deptNames: ['حضانة الأطفال (NICU)']
  },
  {
    fullName: 'د. منيرة فايد',
    email: 'dr.monira.fayed@matrouh-nursing.edu.eg',
    role: 'evaluating_doctor',
    jobTitle: 'مسئول أريا الإدارة وعناية باطنة',
    gender: 'female',
    category: 'doctor',
    deptNames: ['عناية باطنة', 'إدارة التمريض والتدريب']
  },
  {
    fullName: 'د. إلهام علي',
    email: 'dr.elham.ali@matrouh-nursing.edu.eg',
    role: 'evaluating_doctor',
    jobTitle: 'مسئول أريا الكلى وعناية القلب',
    gender: 'female',
    category: 'doctor',
    deptNames: ['قسم الغسيل الكلوي', 'عناية القلب (CCU)']
  },
  {
    fullName: 'د. ريم رأفت',
    email: 'dr.reem.raafat@matrouh-nursing.edu.eg',
    role: 'evaluating_doctor',
    jobTitle: 'مسئول أريا العمليات والجراحة',
    gender: 'female',
    category: 'doctor',
    deptNames: ['قسم العمليات والجراحة', 'عناية جراحة']
  },

  // --- LEADERS (الليدرات) ---
  {
    fullName: 'عمار ياسر',
    email: 'ammar.yasser@matrouh-nursing.edu.eg',
    role: 'leader',
    jobTitle: 'ليدر الامتياز',
    gender: 'male',
    category: 'leader'
  },
  {
    fullName: 'عمر بشير',
    email: 'omar.basheer@matrouh-nursing.edu.eg',
    role: 'leader',
    jobTitle: 'ليدر الامتياز',
    gender: 'male',
    category: 'leader'
  },
  {
    fullName: 'مصطفى لطفي',
    email: 'mostafa.lotfy@matrouh-nursing.edu.eg',
    role: 'leader',
    jobTitle: 'ليدر الامتياز',
    gender: 'male',
    category: 'leader'
  },
  {
    fullName: 'صفاء محمد',
    email: 'safaa.leader@matrouh-nursing.edu.eg',
    role: 'leader',
    jobTitle: 'ليدر الامتياز',
    gender: 'female',
    category: 'leader'
  },
  {
    fullName: 'منار صبحي',
    email: 'manar.sobhy@matrouh-nursing.edu.eg',
    role: 'leader',
    jobTitle: 'ليدر الامتياز',
    gender: 'female',
    category: 'leader'
  },
  {
    fullName: 'براء إبراهيم',
    email: 'baraa.leader@matrouh-nursing.edu.eg',
    role: 'leader',
    jobTitle: 'ليدر الامتياز',
    gender: 'male',
    category: 'leader'
  }
];

async function setupProductionAccounts() {
  console.log('================================================================');
  console.log('🚀 CLEANING TEST DATA & PROVISIONING REAL PRODUCTION ACCOUNTS 🚀');
  console.log('================================================================\n');

  // 1. Ensure required hospital departments exist
  console.log('1. Ensuring all Hospital Departments exist...');
  const extraDepts = [
    {
      id: 'a0000001-0000-0000-0000-000000000007',
      name_ar: 'قسم العمليات والجراحة',
      name_en: 'Operating Room & Surgery',
      description: 'العمليات الجراحية العامة والحرجة والتعقيم',
      capacity: 20,
      is_active: true
    },
    {
      id: 'a0000001-0000-0000-0000-000000000008',
      name_ar: 'إدارة التمريض والتدريب',
      name_en: 'Nursing Administration',
      description: 'إدارة وتدريب الكوادر التمريضية والإشراف الميداني',
      capacity: 30,
      is_active: true
    }
  ];

  for (const dept of extraDepts) {
    try {
      await adminRest('departments', {
        method: 'POST',
        prefer: 'resolution=merge-duplicates,return=representation',
        body: dept
      });
      console.log(`  ✓ Department verified: ${dept.name_ar}`);
    } catch (e) {
      console.log(`  Note on department ${dept.name_ar}: ${e.message}`);
    }
  }

  const allDepts = await adminRest('departments');
  const deptMap = {};
  allDepts.forEach(d => { deptMap[d.name_ar] = d.id; });

  // 2. Remove all test users from Auth
  console.log('\n2. Cleaning old test users from Auth...');
  const usersList = await authAdmin('users');
  for (const u of (usersList.users || [])) {
    if (u.email && (u.email.includes('@matrouh-internship.test') || u.email.includes('@matrouh-qa.test') || u.email.includes('test.'))) {
      try {
        await authAdmin(`users/${u.id}`, { method: 'DELETE' });
        console.log(`  🗑️ Deleted test auth user: ${u.email} (${u.id})`);
      } catch (e) {
        console.warn(`  Failed to delete ${u.email}:`, e.message);
      }
    }
  }

  // Also clean test profiles
  try {
    await adminRest('profiles?email=ilike.*@matrouh-internship.test', { method: 'DELETE' });
    await adminRest('profiles?email=ilike.*@matrouh-qa.test', { method: 'DELETE' });
  } catch (_) {}

  // 3. Provision real production accounts
  console.log('\n3. Creating Real Production Accounts in Supabase Auth & Profiles...');
  const createdAccounts = [];

  for (const acc of ACCOUNTS) {
    let authUser = null;
    try {
      const createRes = await authAdmin('users', {
        method: 'POST',
        body: {
          email: acc.email,
          password: DEFAULT_PASSWORD,
          email_confirm: true,
          user_metadata: {
            full_name: acc.fullName,
            role: acc.role,
            gender: acc.gender
          }
        }
      });
      authUser = createRes.user || createRes;
    } catch (e) {
      const existing = (await authAdmin('users')).users.find(u => u.email === acc.email);
      if (existing) {
        authUser = existing;
        await authAdmin(`users/${authUser.id}`, {
          method: 'PUT',
          body: { password: DEFAULT_PASSWORD, email_confirm: true }
        });
      } else {
        console.error(`  ❌ Failed to create auth user ${acc.email}:`, e.message);
        continue;
      }
    }

    if (!authUser || !authUser.id) {
      console.error(`  ❌ No user ID returned for ${acc.email}`);
      continue;
    }

    // Upsert Profile
    await adminRest('profiles', {
      method: 'POST',
      prefer: 'resolution=merge-duplicates,return=representation',
      body: {
        id: authUser.id,
        email: acc.email,
        full_name: acc.fullName,
        role: acc.role,
        gender: acc.gender,
        is_approved: true,
        registration_status: 'approved',
        phone_number: '01000000000',
        national_id: '30000000000000',
        university_code: acc.role === 'leader' ? `LDR-${authUser.id.slice(0, 5).toUpperCase()}` : null
      }
    });

    // If evaluating doctor or admin_and_doctor, link to department_supervisors
    if (acc.deptNames && acc.deptNames.length > 0) {
      for (const deptName of acc.deptNames) {
        const deptId = deptMap[deptName];
        if (deptId) {
          try {
            await adminRest('department_supervisors', {
              method: 'POST',
              prefer: 'resolution=merge-duplicates,return=representation',
              body: {
                department_id: deptId,
                doctor_id: authUser.id,
                male_capacity: 4,
                female_capacity: 7,
                assignment_status: 'approved',
                is_active: true
              }
            });
            console.log(`    🔗 Linked ${acc.fullName} as supervisor for: ${deptName}`);
          } catch (e) {
            console.warn(`    ⚠️ Linking error for ${deptName}:`, e.message);
          }
        }
      }
    }

    console.log(`  ✅ [${acc.role.toUpperCase()}] ${acc.fullName} -> ${acc.email}`);
    createdAccounts.push({
      ...acc,
      id: authUser.id,
      password: DEFAULT_PASSWORD
    });
  }

  console.log('\n================================================================');
  console.log('🎉 ALL REAL PRODUCTION ACCOUNTS CREATED SUCCESSFULLY 🎉');
  console.log(`Total Provisioned: ${createdAccounts.length}`);
  console.log('Default Password for all: ' + DEFAULT_PASSWORD);
  console.log('================================================================\n');
}

setupProductionAccounts().catch(err => {
  console.error('Fatal Setup Error:', err);
  process.exit(1);
});
