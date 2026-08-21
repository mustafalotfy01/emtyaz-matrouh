enum ArticleCategory { disease, procedure, emergency, medication, skill }

class KnowledgeArticle {
  final String id;
  final String title;
  final String summary;
  final ArticleCategory category;
  final String definition;
  final List<String> indications;
  final List<String> equipment;
  final List<String> steps;
  final List<String> aftercare;
  final String references;

  KnowledgeArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.definition,
    required this.indications,
    required this.equipment,
    required this.steps,
    required this.aftercare,
    required this.references,
  });

  static List<KnowledgeArticle> defaultLibrary() {
    return [
      KnowledgeArticle(
        id: 'k-1',
        title: 'تركيب القسطرة البولية (Foley Catheter Insertion)',
        summary: 'دليل الخطوات المعقمة والتجهيزات اللازمة لتركيب وتثبيت قسطرة البول للذكور والإناث',
        category: ArticleCategory.procedure,
        definition: 'إجراء تمريضي معقم يتضمن إدخال أنبوب مرن عبر مجرى البول إلى المثانة لتصريف البول.',
        indications: [
          'احتباس البول الحاد',
          'متابعة كمية البول بدقة لدى مرضي العناية الحرجة',
          'قبل الجراحات الكبرى'
        ],
        equipment: [
          'قسطرة فولي معقمة مقاس مناسب (14F - 16F)',
          'كيس جمع بول معقم',
          'قفازات معقمة ومحلول مطهر',
          'جل مزيّت معقم',
          'سرنجة 10 مل بها ماء معقم لتعبئة البالون'
        ],
        steps: [
          'التحقق من هوية المريض وشرح الإجراء لتخفيف القلق',
          'غسل اليدين وارتداء القفازات المعقمة مع الحفاظ على البيئة المعقمة',
          'تنظيف وتطهير فتحة مجرى البول بمسحات مطهرة',
          'تشحيم رأس القسطرة بالجل المعقم وإدخالها ببطء حتى خروج البول',
          'نفخ بالون القسطرة بـ 10 مل ماء معقم وسحبها برفق للتأكد من التثبيت',
          'توصيل القسطرة بكيس الجمع وتثبيتها على فخذ المريض'
        ],
        aftercare: [
          'تثبيت كيس جمع البول بمستوى أقل من المثانة لتفادي الارتجاع',
          'قياس وتسجيل كمية ولون البول كل شيفت',
          'العناية اليومية ونظافة فتحة مجرى البول'
        ],
        references: 'Nursing Skills Reference 2026 - Matrouh Nursing Faculty Standard Guidelines',
      ),
      KnowledgeArticle(
        id: 'k-2',
        title: 'تركيب الرايل التغذوي (Nasogastric Tube - NG Tube)',
        summary: 'إجراء إدخال أنبوب التغذية والنزح المعدي عبر الأنف وتأكيد موقعه بالاستماع',
        category: ArticleCategory.procedure,
        definition: 'إدخال أنبوب مطاطي مرن عبر الأنف مروراً بالمريء واستقراره في المعدة.',
        indications: ['التغذية المعوية لغير القادرين على البلع', 'نزح محتويات المعدة في حالات الانسداد'],
        equipment: ['أنبوب رايل مقاس مناسب', 'سماعة طبية وسرنجة 50 مل', 'جل مزيّت وشريط لاصق'],
        steps: [
          'قياس الطول المطلوب (NEX: أنف -> أذن -> عظمة القص)',
          'تشحيم الأنبوب وتوجيهه للأنسل نحو المريء مع توجيه المريض للبلع',
          'التحقق من استقرار الأنبوب بالمعدة بحقن 20 مل هواء والاستماع بالسماعة فوق المعدة'
        ],
        aftercare: ['تثبيت الأنبوب على الأنف بشريط لاصق لمنع الإزاحة'],
        references: 'Clinical Nursing Manual 2026',
      ),
      KnowledgeArticle(
        id: 'k-3',
        title: 'الحماض التنفسي الحاد (Acute Respiratory Acidosis)',
        summary: 'أسبابه وعلاماته السريرية ودور التمريض في العناية المركزة',
        category: ArticleCategory.disease,
        definition: 'اضطراب في التوازن الحمضي القاعدي بالدم ينجم عن احتباس CO2 بسبب نقص التهوية الرئوية.',
        indications: ['ضيق التنفس الشديد', 'زرقة الشفاه والتشتت الذهني'],
        equipment: ['جهاز ABG', 'قناع أكسجين', 'جهاز تنفس صناعي'],
        steps: ['قياس غازات الدم الشريانية', 'تأمين مجرى الهواء بالأكسجين أو التنبيب'],
        aftercare: ['متابعة دورية للـ ABG وضغط الدم'],
        references: 'Matrouh ICU Clinical Practice Guide',
      ),
    ];
  }
}
