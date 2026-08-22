enum QuestionType { mcq, trueFalse, caseStudy }

extension QuestionTypeExt on QuestionType {
  String get displayNameAr {
    switch (this) {
      case QuestionType.mcq:
        return 'اختيار من متعدد';
      case QuestionType.trueFalse:
        return 'صح أم خطأ';
      case QuestionType.caseStudy:
        return 'دراسة حالة سريرية';
    }
  }

  String toDbString() {
    switch (this) {
      case QuestionType.mcq:
        return 'mcq';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.caseStudy:
        return 'case_study';
    }
  }
}

class QuizQuestion {
  final String id;
  final String quizId;
  final String questionText;
  final QuestionType type;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final int durationSeconds;
  final int orderIndex;

  QuizQuestion({
    required this.id,
    required this.quizId,
    required this.questionText,
    required this.type,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    this.durationSeconds = 30,
    this.orderIndex = 0,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    QuestionType qType = QuestionType.mcq;
    final typeStr = json['type']?.toString().toLowerCase();
    if (typeStr == 'true_false' || typeStr == 'truefalse') {
      qType = QuestionType.trueFalse;
    } else if (typeStr == 'case_study' || typeStr == 'casestudy') {
      qType = QuestionType.caseStudy;
    }

    List<String> parsedOptions = [];
    final rawOptions = json['options'];
    if (rawOptions is List) {
      parsedOptions = rawOptions.map((o) => o.toString()).toList();
    } else if (rawOptions is Map) {
      parsedOptions = rawOptions.values.map((o) => o.toString()).toList();
    }

    if (parsedOptions.isEmpty && qType == QuestionType.trueFalse) {
      parsedOptions = ['صح', 'خطأ'];
    }

    return QuizQuestion(
      id: json['id']?.toString() ?? '',
      quizId: json['quiz_id']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? '',
      type: qType,
      options: parsedOptions,
      correctOptionIndex: (json['correct_option_index'] as num?)?.toInt() ?? 0,
      explanation: json['explanation']?.toString() ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 30,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
    );
  }
}

class Quiz {
  final String id;
  final String title;
  final String description;
  final String departmentName;
  final String? departmentId;
  final int timeLimitMinutes;
  final int passingScorePercentage;
  final bool isActive;
  final List<QuizQuestion> questions;

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.departmentName,
    this.departmentId,
    required this.timeLimitMinutes,
    required this.passingScorePercentage,
    this.isActive = true,
    required this.questions,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    List<QuizQuestion> qList = [];
    if (json['quiz_questions'] is List) {
      qList = (json['quiz_questions'] as List)
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
    }

    return Quiz(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      departmentName: json['departments'] != null && json['departments']['name_ar'] != null
          ? json['departments']['name_ar'].toString()
          : (json['department_name']?.toString() ?? 'قسم التمريض العام'),
      departmentId: json['department_id']?.toString(),
      timeLimitMinutes: (json['time_limit_minutes'] as num?)?.toInt() ?? 10,
      passingScorePercentage: (json['passing_score_percentage'] ?? json['passing_score'] as num?)?.toInt() ?? 70,
      isActive: json['is_active'] != false,
      questions: qList,
    );
  }
}

class QuizAttemptResult {
  final String quizId;
  final String studentId;
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int unansweredCount;
  final double scorePercentage;
  final bool passed;
  final int completionTimeSeconds;
  final Map<int, int?> userAnswers;

  QuizAttemptResult({
    required this.quizId,
    required this.studentId,
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.unansweredCount,
    required this.scorePercentage,
    required this.passed,
    required this.completionTimeSeconds,
    required this.userAnswers,
  });
}

class QuizAttempt {
  final String id;
  final String quizId;
  final String studentId;
  final double scorePercentage;
  final bool passed;
  final DateTime completedAt;

  QuizAttempt({
    required this.id,
    required this.quizId,
    required this.studentId,
    required this.scorePercentage,
    required this.passed,
    required this.completedAt,
  });

  factory QuizAttempt.fromJson(Map<String, dynamic> json) {
    return QuizAttempt(
      id: json['id']?.toString() ?? '',
      quizId: json['quiz_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      scorePercentage: (json['score_percentage'] as num?)?.toDouble() ?? 0.0,
      passed: json['passed'] == true,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'].toString())
          : DateTime.now(),
    );
  }
}
