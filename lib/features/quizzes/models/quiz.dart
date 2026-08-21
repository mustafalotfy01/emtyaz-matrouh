enum QuestionType { mcq, trueFalse, caseStudy }

class QuizQuestion {
  final String id;
  final String questionText;
  final QuestionType type;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.type,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });
}

class Quiz {
  final String id;
  final String title;
  final String description;
  final String departmentName;
  final int timeLimitMinutes;
  final int passingScorePercentage;
  final List<QuizQuestion> questions;

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.departmentName,
    required this.timeLimitMinutes,
    required this.passingScorePercentage,
    required this.questions,
  });

  static List<Quiz> defaultQuizzes() {
    return [
      Quiz(
        id: 'quiz-1',
        title: 'اختبار إجراءات قسطرة البول والتغذية الأنبوبية (Emergency & ICU)',
        description: 'اختبار تقييمي لقياس المعرفة العملية لخطوات Foley Catheter و NG Tube',
        departmentName: 'قسم الطوارئ والعناية',
        timeLimitMinutes: 10,
        passingScorePercentage: 70,
        questions: [
          QuizQuestion(
            id: 'q1',
            questionText: 'ما هي المسافة السليمة لتشحيم قسطرة البول للذكور قبل الإدخال؟',
            type: QuestionType.mcq,
            options: ['1 - 2 سم', '5 - 7 سم', '15 - 20 سم', '30 سم'],
            correctOptionIndex: 2,
            explanation: 'في الذكور يجب تشحيم القسطرة بجل المزيّت لمسافة 15 إلى 20 سم لتقليل الاحتكاك بمجرى البول الطويل.',
          ),
          QuizQuestion(
            id: 'q2',
            questionText: 'عند تركيب الرايل (NG Tube)، يتم قياس الطول المطلوب من أذن المريض إلى الأنف ثم إلى الصدر (Xiphoid process)؟',
            type: QuestionType.trueFalse,
            options: ['صح', 'خطأ'],
            correctOptionIndex: 0,
            explanation: 'القياس الصحيح هو من أرنبة الأنف إلى شحمة الأذن ثم إلى أسفل العظمة القصية (NEX Measurement).',
          ),
          QuizQuestion(
            id: 'q3',
            questionText: 'مريض بالعناية الباطنية يعاني من هبوط في مستوى الوعي وتسارع بالأنفاس (ABG: pH 7.25, PaCO2 55). ما هو إجراء التمريض الأولي؟',
            type: QuestionType.caseStudy,
            options: [
              'إعطاء المريض مسكن قوي',
              'تجهيز أدوات التنفس الصناعي والشفط الهوائي فوراً للتنبيب الوريدي',
              'إيقاف الأكسجين تماماً',
              'إعطاء المريض محلول ملحي بالوريد'
            ],
            correctOptionIndex: 1,
            explanation: 'الحالة تعبر عن الحماض التنفسي (Respiratory Acidosis) وتتطلب تأمين مجرى الهواء والتنفس الميكانيكي.',
          ),
        ],
      ),
      Quiz(
        id: 'quiz-2',
        title: 'أساسيات العناية بالقلب وحساب جرعات الأدوية الحرجة',
        description: 'اختبار الحسابات التمريضية وجرعات الإينوتروبس في قسم CCU',
        departmentName: 'عناية القلب (CCU)',
        timeLimitMinutes: 15,
        passingScorePercentage: 80,
        questions: [
          QuizQuestion(
            id: 'q2-1',
            questionText: 'مطلوب إعطاء 500 مل محلول على مدار 4 ساعات بواسطة جهاز تنقيط بمعامل 15 نقطة/مل. كم عدد النقاط/دقيقة؟',
            type: QuestionType.mcq,
            options: ['31 نقطة/دقيقة', '52 نقطة/دقيقة', '60 نقطة/دقيقة', '100 نقطة/دقيقة'],
            correctOptionIndex: 0,
            explanation: 'الحساب: (500 × 15) ÷ (4 × 60) = 7500 ÷ 240 = 31.25 نقطة/دقيقة.',
          ),
        ],
      ),
    ];
  }
}
