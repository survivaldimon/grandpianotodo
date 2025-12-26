# MODELS.md — Dart модели данных Kabinet

## Базовые классы

### BaseModel

```dart
/// Базовый класс для всех моделей с общими полями
abstract class BaseModel {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  
  const BaseModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });
  
  bool get isArchived => archivedAt != null;
}
```

---

## Auth / Profile

```dart
/// Профиль пользователя (расширение auth.users)
/// Не наследует BaseModel, так как профили не архивируются
class Profile {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'avatar_url': avatarUrl,
  };
}
```

---

## Institution

```dart
/// Учебное заведение
class Institution extends BaseModel {
  final String name;
  final String ownerId;
  final String inviteCode;
  
  const Institution({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
  });
  
  factory Institution.fromJson(Map<String, dynamic> json) => Institution(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    archivedAt: json['archived_at'] != null 
        ? DateTime.parse(json['archived_at'] as String) 
        : null,
    name: json['name'] as String,
    ownerId: json['owner_id'] as String,
    inviteCode: json['invite_code'] as String,
  );
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'owner_id': ownerId,
  };
  
  Institution copyWith({
    String? name,
  }) => Institution(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    name: name ?? this.name,
    ownerId: ownerId,
    inviteCode: inviteCode,
  );
}
```

---

## InstitutionMember

```dart
/// Права доступа участника заведения
class MemberPermissions {
  final bool manageInstitution;
  final bool manageRooms;
  final bool manageMembers;
  final bool manageSubjects;
  final bool manageStudents;
  final bool manageGroups;
  final bool manageLessonTypes;
  final bool managePaymentPlans;
  final bool createLessons;
  final bool editOwnLessons;
  final bool editAllLessons;
  final bool deleteLessons;
  final bool viewAllSchedule;
  final bool managePayments;
  final bool viewPayments;
  final bool viewStatistics;
  final bool archiveData;
  
  const MemberPermissions({
    this.manageInstitution = false,
    this.manageRooms = false,
    this.manageMembers = false,
    this.manageSubjects = false,
    this.manageStudents = false,
    this.manageGroups = false,
    this.manageLessonTypes = false,
    this.managePaymentPlans = false,
    this.createLessons = true,
    this.editOwnLessons = true,
    this.editAllLessons = false,
    this.deleteLessons = false,
    this.viewAllSchedule = true,
    this.managePayments = false,
    this.viewPayments = false,
    this.viewStatistics = false,
    this.archiveData = false,
  });
  
  /// Полные права (для владельца)
  factory MemberPermissions.owner() => const MemberPermissions(
    manageInstitution: true,
    manageRooms: true,
    manageMembers: true,
    manageSubjects: true,
    manageStudents: true,
    manageGroups: true,
    manageLessonTypes: true,
    managePaymentPlans: true,
    createLessons: true,
    editOwnLessons: true,
    editAllLessons: true,
    deleteLessons: true,
    viewAllSchedule: true,
    managePayments: true,
    viewPayments: true,
    viewStatistics: true,
    archiveData: true,
  );
  
  /// Права по умолчанию для нового участника
  factory MemberPermissions.defaultTeacher() => const MemberPermissions();
  
  factory MemberPermissions.fromJson(Map<String, dynamic> json) => MemberPermissions(
    manageInstitution: json['manage_institution'] as bool? ?? false,
    manageRooms: json['manage_rooms'] as bool? ?? false,
    manageMembers: json['manage_members'] as bool? ?? false,
    manageSubjects: json['manage_subjects'] as bool? ?? false,
    manageStudents: json['manage_students'] as bool? ?? false,
    manageGroups: json['manage_groups'] as bool? ?? false,
    manageLessonTypes: json['manage_lesson_types'] as bool? ?? false,
    managePaymentPlans: json['manage_payment_plans'] as bool? ?? false,
    createLessons: json['create_lessons'] as bool? ?? true,
    editOwnLessons: json['edit_own_lessons'] as bool? ?? true,
    editAllLessons: json['edit_all_lessons'] as bool? ?? false,
    deleteLessons: json['delete_lessons'] as bool? ?? false,
    viewAllSchedule: json['view_all_schedule'] as bool? ?? true,
    managePayments: json['manage_payments'] as bool? ?? false,
    viewPayments: json['view_payments'] as bool? ?? false,
    viewStatistics: json['view_statistics'] as bool? ?? false,
    archiveData: json['archive_data'] as bool? ?? false,
  );
  
  Map<String, dynamic> toJson() => {
    'manage_institution': manageInstitution,
    'manage_rooms': manageRooms,
    'manage_members': manageMembers,
    'manage_subjects': manageSubjects,
    'manage_students': manageStudents,
    'manage_groups': manageGroups,
    'manage_lesson_types': manageLessonTypes,
    'manage_payment_plans': managePaymentPlans,
    'create_lessons': createLessons,
    'edit_own_lessons': editOwnLessons,
    'edit_all_lessons': editAllLessons,
    'delete_lessons': deleteLessons,
    'view_all_schedule': viewAllSchedule,
    'manage_payments': managePayments,
    'view_payments': viewPayments,
    'view_statistics': viewStatistics,
    'archive_data': archiveData,
  };
  
  MemberPermissions copyWith({
    bool? manageInstitution,
    bool? manageRooms,
    bool? manageMembers,
    bool? manageSubjects,
    bool? manageStudents,
    bool? manageGroups,
    bool? manageLessonTypes,
    bool? managePaymentPlans,
    bool? createLessons,
    bool? editOwnLessons,
    bool? editAllLessons,
    bool? deleteLessons,
    bool? viewAllSchedule,
    bool? managePayments,
    bool? viewPayments,
    bool? viewStatistics,
    bool? archiveData,
  }) => MemberPermissions(
    manageInstitution: manageInstitution ?? this.manageInstitution,
    manageRooms: manageRooms ?? this.manageRooms,
    manageMembers: manageMembers ?? this.manageMembers,
    manageSubjects: manageSubjects ?? this.manageSubjects,
    manageStudents: manageStudents ?? this.manageStudents,
    manageGroups: manageGroups ?? this.manageGroups,
    manageLessonTypes: manageLessonTypes ?? this.manageLessonTypes,
    managePaymentPlans: managePaymentPlans ?? this.managePaymentPlans,
    createLessons: createLessons ?? this.createLessons,
    editOwnLessons: editOwnLessons ?? this.editOwnLessons,
    editAllLessons: editAllLessons ?? this.editAllLessons,
    deleteLessons: deleteLessons ?? this.deleteLessons,
    viewAllSchedule: viewAllSchedule ?? this.viewAllSchedule,
    managePayments: managePayments ?? this.managePayments,
    viewPayments: viewPayments ?? this.viewPayments,
    viewStatistics: viewStatistics ?? this.viewStatistics,
    archiveData: archiveData ?? this.archiveData,
  );
}

/// Участник заведения
class InstitutionMember {
  final String id;
  final String institutionId;
  final String userId;
  final String roleName;
  final MemberPermissions permissions;
  final DateTime joinedAt;
  final DateTime? archivedAt;
  
  /// Профиль пользователя (join)
  final Profile? profile;
  
  const InstitutionMember({
    required this.id,
    required this.institutionId,
    required this.userId,
    required this.roleName,
    required this.permissions,
    required this.joinedAt,
    this.archivedAt,
    this.profile,
  });
  
  bool get isArchived => archivedAt != null;
  
  factory InstitutionMember.fromJson(Map<String, dynamic> json) => InstitutionMember(
    id: json['id'] as String,
    institutionId: json['institution_id'] as String,
    userId: json['user_id'] as String,
    roleName: json['role_name'] as String,
    permissions: MemberPermissions.fromJson(json['permissions'] as Map<String, dynamic>),
    joinedAt: DateTime.parse(json['joined_at'] as String),
    archivedAt: json['archived_at'] != null 
        ? DateTime.parse(json['archived_at'] as String) 
        : null,
    profile: json['profiles'] != null 
        ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
        : null,
  );
  
  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'user_id': userId,
    'role_name': roleName,
    'permissions': permissions.toJson(),
  };
}
```

---

## Room

```dart
/// Кабинет заведения
class Room extends BaseModel {
  final String institutionId;
  final String name;
  final String? number;
  final int sortOrder;
  
  const Room({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.number,
    this.sortOrder = 0,
  });
  
  /// Отображаемое название (номер + название или просто название)
  String get displayName => number != null ? '$number — $name' : name;
  
  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    archivedAt: json['archived_at'] != null 
        ? DateTime.parse(json['archived_at'] as String) 
        : null,
    institutionId: json['institution_id'] as String,
    name: json['name'] as String,
    number: json['number'] as String?,
    sortOrder: json['sort_order'] as int? ?? 0,
  );
  
  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'name': name,
    'number': number,
    'sort_order': sortOrder,
  };
  
  Room copyWith({
    String? name,
    String? number,
    int? sortOrder,
  }) => Room(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    institutionId: institutionId,
    name: name ?? this.name,
    number: number ?? this.number,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}
```

---

## Student

```dart
/// Ученик
class Student extends BaseModel {
  final String institutionId;
  final String name;
  final String? phone;
  final String? comment;
  final int prepaidLessonsCount;
  
  const Student({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.phone,
    this.comment,
    this.prepaidLessonsCount = 0,
  });
  
  /// Есть ли долг (отрицательный баланс)
  bool get hasDebt => prepaidLessonsCount < 0;
  
  /// Количество занятий для отображения (с учётом знака)
  String get prepaidDisplay => prepaidLessonsCount >= 0 
      ? '$prepaidLessonsCount' 
      : '$prepaidLessonsCount';
  
  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    archivedAt: json['archived_at'] != null 
        ? DateTime.parse(json['archived_at'] as String) 
        : null,
    institutionId: json['institution_id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    comment: json['comment'] as String?,
    prepaidLessonsCount: json['prepaid_lessons_count'] as int? ?? 0,
  );
  
  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'name': name,
    'phone': phone,
    'comment': comment,
  };
  
  Student copyWith({
    String? name,
    String? phone,
    String? comment,
    int? prepaidLessonsCount,
  }) => Student(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    institutionId: institutionId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    comment: comment ?? this.comment,
    prepaidLessonsCount: prepaidLessonsCount ?? this.prepaidLessonsCount,
  );
}
```

---

## StudentGroup

```dart
/// Группа учеников
class StudentGroup extends BaseModel {
  final String institutionId;
  final String name;
  final String? comment;
  
  /// Список участников группы (join)
  final List<Student>? members;
  
  const StudentGroup({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.comment,
    this.members,
  });
  
  int get membersCount => members?.length ?? 0;
  
  factory StudentGroup.fromJson(Map<String, dynamic> json) => StudentGroup(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    archivedAt: json['archived_at'] != null 
        ? DateTime.parse(json['archived_at'] as String) 
        : null,
    institutionId: json['institution_id'] as String,
    name: json['name'] as String,
    comment: json['comment'] as String?,
    members: json['student_group_members'] != null
        ? (json['student_group_members'] as List)
            .map((m) => Student.fromJson(m['students'] as Map<String, dynamic>))
            .toList()
        : null,
  );
  
  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'name': name,
    'comment': comment,
  };
  
  StudentGroup copyWith({
    String? name,
    String? comment,
    List<Student>? members,
  }) => StudentGroup(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    institutionId: institutionId,
    name: name ?? this.name,
    comment: comment ?? this.comment,
    members: members ?? this.members,
  );
}

/// Связь ученика с группой
class StudentGroupMember {
  final String id;
  final String groupId;
  final String studentId;
  final DateTime joinedAt;
  
  const StudentGroupMember({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.joinedAt,
  });
  
  factory StudentGroupMember.fromJson(Map<String, dynamic> json) => StudentGroupMember(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    studentId: json['student_id'] as String,
    joinedAt: DateTime.parse(json['joined_at'] as String),
  );
  
  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'student_id': studentId,
  };
}
```

---

## Subject (Предмет)

```dart
/// Предмет/направление (Фортепиано, Вокал, Гитара и т.д.)
class Subject extends BaseModel {
  final String institutionId;
  final String name;
  final String? color; // HEX цвет
  final int sortOrder;
  
  const Subject({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.color,
    this.sortOrder = 0,
  });
  
  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    archivedAt: json['archived_at'] != null 
        ? DateTime.parse(json['archived_at'] as String) 
        : null,
    institutionId: json['institution_id'] as String,
    name: json['name'] as String,
    color: json['color'] as String?,
    sortOrder: json['sort_order'] as int? ?? 0,
  );
  
  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'name': name,
    'color': color,
    'sort_order': sortOrder,
  };
  
  Subject copyWith({
    String? name,
    String? color,
    int? sortOrder,
  }) => Subject(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    institutionId: institutionId,
    name: name ?? this.name,
    color: color ?? this.color,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

/// Связь преподавателя с предметом
class TeacherSubject {
  final String id;
  final String userId;
  final String subjectId;
  final String institutionId;
  final DateTime createdAt;
  
  /// Связанный предмет (join)
  final Subject? subject;
  
  const TeacherSubject({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.institutionId,
    required this.createdAt,
    this.subject,
  });
  
  factory TeacherSubject.fromJson(Map<String, dynamic> json) => TeacherSubject(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    subjectId: json['subject_id'] as String,
    institutionId: json['institution_id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    subject: json['subjects'] != null 
        ? Subject.fromJson(json['subjects'] as Map<String, dynamic>) 
        : null,
  );
  
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'subject_id': subjectId,
    'institution_id': institutionId,
  };
}
```

---

## LessonType

```dart
/// Тип занятия
class LessonType extends BaseModel {
  final String institutionId;
  final String name;
  final int defaultDurationMinutes;
  final double? defaultPrice;
  final bool isGroup;
  final String? color; // HEX цвет
  
  const LessonType({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.defaultDurationMinutes = 60,
    this.defaultPrice,
    this.isGroup = false,
    this.color,
  });
  
  factory LessonType.fromJson(Map<String, dynamic> json) => LessonType(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    archivedAt: json['archived_at'] != null 
        ? DateTime.parse(json['archived_at'] as String) 
        : null,
    institutionId: json['institution_id'] as String,
    name: json['name'] as String,
    defaultDurationMinutes: json['default_duration_minutes'] as int? ?? 60,
    defaultPrice: (json['default_price'] as num?)?.toDouble(),
    isGroup: json['is_group'] as bool? ?? false,
    color: json['color'] as String?,
  );
  
  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'name': name,
    'default_duration_minutes': defaultDurationMinutes,
    'default_price': defaultPrice,
    'is_group': isGroup,
    'color': color,
  };
  
  LessonType copyWith({
    String? name,
    int? defaultDurationMinutes,
    double? defaultPrice,
    bool? isGroup,
    String? color,
  }) => LessonType(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    institutionId: institutionId,
    name: name ?? this.name,
    defaultDurationMinutes: defaultDurationMinutes ?? this.defaultDurationMinutes,
    defaultPrice: defaultPrice ?? this.defaultPrice,
    isGroup: isGroup ?? this.isGroup,
    color: color ?? this.color,
  );
}
```

---

## Lesson

```dart
/// Статус занятия
enum LessonStatus {
  scheduled,
  completed,
  cancelled,
  rescheduled;
  
  String get displayName {
    switch (this) {
      case LessonStatus.scheduled:
        return 'Запланировано';
      case LessonStatus.completed:
        return 'Проведено';
      case LessonStatus.cancelled:
        return 'Отменено';
      case LessonStatus.rescheduled:
        return 'Перенесено';
    }
  }
  
  static LessonStatus fromString(String value) {
    return LessonStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LessonStatus.scheduled,
    );
  }
}

/// Занятие
class Lesson extends BaseModel {
  final String institutionId;
  final String roomId;
  final String teacherId;
  final String? subjectId;     // Предмет занятия
  final String? lessonTypeId;
  final String? studentId;  // Для индивидуальных
  final String? groupId;    // Для групповых
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final LessonStatus status;
  final String? comment;
  final String createdBy;
  
  /// Связанные объекты (join)
  final Room? room;
  final Profile? teacher;
  final Subject? subject;
  final LessonType? lessonType;
  final Student? student;
  final StudentGroup? group;
  
  const Lesson({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.roomId,
    required this.teacherId,
    this.subjectId,
    this.lessonTypeId,
    this.studentId,
    this.groupId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.status = LessonStatus.scheduled,
    this.comment,
    required this.createdBy,
    this.room,
    this.teacher,
    this.subject,
    this.lessonType,
    this.student,
    this.group,
  });
  
  /// Индивидуальное ли занятие
  bool get isIndividual => studentId != null;
  
  /// Групповое ли занятие
  bool get isGroupLesson => groupId != null;
  
  /// Длительность в минутах
  int get durationMinutes {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return endMinutes - startMinutes;
  }
  
  /// Название участника (ученик или группа)
  String get participantName {
    if (student != null) return student!.name;
    if (group != null) return group!.name;
    return 'Не указан';
  }
  
  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    archivedAt: json['archived_at'] != null 
        ? DateTime.parse(json['archived_at'] as String) 
        : null,
    institutionId: json['institution_id'] as String,
    roomId: json['room_id'] as String,
    teacherId: json['teacher_id'] as String,
    subjectId: json['subject_id'] as String?,
    lessonTypeId: json['lesson_type_id'] as String?,
    studentId: json['student_id'] as String?,
    groupId: json['group_id'] as String?,
    date: DateTime.parse(json['date'] as String),
    startTime: _parseTime(json['start_time'] as String),
    endTime: _parseTime(json['end_time'] as String),
    status: LessonStatus.fromString(json['status'] as String),
    comment: json['comment'] as String?,
    createdBy: json['created_by'] as String,
    room: json['rooms'] != null 
        ? Room.fromJson(json['rooms'] as Map<String, dynamic>) 
        : null,
    teacher: json['profiles'] != null 
        ? Profile.fromJson(json['profiles'] as Map<String, dynamic>) 
        : null,
    subject: json['subjects'] != null 
        ? Subject.fromJson(json['subjects'] as Map<String, dynamic>) 
        : null,
    lessonType: json['lesson_types'] != null 
        ? LessonType.fromJson(json['lesson_types'] as Map<String, dynamic>) 
        : null,
    student: json['students'] != null 
        ? Student.fromJson(json['students'] as Map<String, dynamic>) 
        : null,
    group: json['student_groups'] != null 
        ? StudentGroup.fromJson(json['student_groups'] as Map<String, dynamic>) 
        : null,
  );
  
  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'room_id': roomId,
    'teacher_id': teacherId,
    'subject_id': subjectId,
    'lesson_type_id': lessonTypeId,
    'student_id': studentId,
    'group_id': groupId,
    'date': date.toIso8601String().split('T').first,
    'start_time': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
    'end_time': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
    'status': status.name,
    'comment': comment,
    'created_by': createdBy,
  };
  
  Lesson copyWith({
    String? roomId,
    String? teacherId,
    String? subjectId,
    String? lessonTypeId,
    String? studentId,
    String? groupId,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    LessonStatus? status,
    String? comment,
  }) => Lesson(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    institutionId: institutionId,
    roomId: roomId ?? this.roomId,
    teacherId: teacherId ?? this.teacherId,
    subjectId: subjectId ?? this.subjectId,
    lessonTypeId: lessonTypeId ?? this.lessonTypeId,
    studentId: studentId ?? this.studentId,
    groupId: groupId ?? this.groupId,
    date: date ?? this.date,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    status: status ?? this.status,
    comment: comment ?? this.comment,
    createdBy: createdBy,
    room: room,
    teacher: teacher,
    subject: subject,
    lessonType: lessonType,
    student: student,
    group: group,
  );
  
  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}

/// Участник группового занятия
class LessonStudent {
  final String id;
  final String lessonId;
  final String studentId;
  final bool attended;
  
  /// Связанный студент (join)
  final Student? student;
  
  const LessonStudent({
    required this.id,
    required this.lessonId,
    required this.studentId,
    this.attended = true,
    this.student,
  });
  
  factory LessonStudent.fromJson(Map<String, dynamic> json) => LessonStudent(
    id: json['id'] as String,
    lessonId: json['lesson_id'] as String,
    studentId: json['student_id'] as String,
    attended: json['attended'] as bool? ?? true,
    student: json['students'] != null 
        ? Student.fromJson(json['students'] as Map<String, dynamic>) 
        : null,
  );
  
  Map<String, dynamic> toJson() => {
    'lesson_id': lessonId,
    'student_id': studentId,
    'attended': attended,
  };
}
```

---

## LessonHistory

```dart
/// Запись истории изменений занятия
class LessonHistory {
  final String id;
  final String lessonId;
  final String changedBy;
  final DateTime changedAt;
  final String action;
  final Map<String, dynamic> changes;
  
  /// Профиль того, кто изменил (join)
  final Profile? changedByProfile;
  
  const LessonHistory({
    required this.id,
    required this.lessonId,
    required this.changedBy,
    required this.changedAt,
    required this.action,
    required this.changes,
    this.changedByProfile,
  });
  
  String get actionDisplayName {
    switch (action) {
      case 'created':
        return 'Создано';
      case 'updated':
        return 'Изменено';
      case 'status_changed':
        return 'Изменён статус';
      case 'archived':
        return 'Архивировано';
      default:
        return action;
    }
  }
  
  factory LessonHistory.fromJson(Map<String, dynamic> json) => LessonHistory(
    id: json['id'] as String,
    lessonId: json['lesson_id'] as String,
    changedBy: json['changed_by'] as String,
    changedAt: DateTime.parse(json['changed_at'] as String),
    action: json['action'] as String,
    changes: json['changes'] as Map<String, dynamic>,
    changedByProfile: json['profiles'] != null 
        ? Profile.fromJson(json['profiles'] as Map<String, dynamic>) 
        : null,
  );
}
```

---

## PaymentPlan

```dart
/// Тариф оплаты
class PaymentPlan extends BaseModel {
  final String institutionId;
  final String name;
  final double price;
  final int lessonsCount;
  
  const PaymentPlan({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    required this.price,
    required this.lessonsCount,
  });
  
  /// Цена за одно занятие
  double get pricePerLesson => price / lessonsCount;
  
  /// Отображение: "8 занятий — 20 000 ₸"
  String get displayName => '$lessonsCount занятий — ${price.toStringAsFixed(0)} ₸';
  
  factory PaymentPlan.fromJson(Map<String, dynamic> json) => PaymentPlan(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    archivedAt: json['archived_at'] != null 
        ? DateTime.parse(json['archived_at'] as String) 
        : null,
    institutionId: json['institution_id'] as String,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    lessonsCount: json['lessons_count'] as int,
  );
  
  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'name': name,
    'price': price,
    'lessons_count': lessonsCount,
  };
  
  PaymentPlan copyWith({
    String? name,
    double? price,
    int? lessonsCount,
  }) => PaymentPlan(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
    institutionId: institutionId,
    name: name ?? this.name,
    price: price ?? this.price,
    lessonsCount: lessonsCount ?? this.lessonsCount,
  );
}
```

---

## Payment

```dart
/// Оплата
class Payment {
  final String id;
  final String institutionId;
  final String studentId;
  final String? paymentPlanId;
  final double amount;              // Может быть отрицательным для корректировок
  final int lessonsCount;           // Может быть отрицательным для корректировок
  final bool isCorrection;          // Флаг корректирующей записи
  final String? correctionReason;   // Причина корректировки (обязательна если isCorrection=true)
  final DateTime paidAt;
  final String recordedBy;
  final String? comment;
  final DateTime createdAt;

  /// Связанные объекты (join)
  final Student? student;
  final PaymentPlan? paymentPlan;
  final Profile? recordedByProfile;

  const Payment({
    required this.id,
    required this.institutionId,
    required this.studentId,
    this.paymentPlanId,
    required this.amount,
    required this.lessonsCount,
    this.isCorrection = false,
    this.correctionReason,
    required this.paidAt,
    required this.recordedBy,
    this.comment,
    required this.createdAt,
    this.student,
    this.paymentPlan,
    this.recordedByProfile,
  });

  /// Это корректирующая запись с отрицательными значениями?
  bool get isNegative => amount < 0 || lessonsCount < 0;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    institutionId: json['institution_id'] as String,
    studentId: json['student_id'] as String,
    paymentPlanId: json['payment_plan_id'] as String?,
    amount: (json['amount'] as num).toDouble(),
    lessonsCount: json['lessons_count'] as int,
    isCorrection: json['is_correction'] as bool? ?? false,
    correctionReason: json['correction_reason'] as String?,
    paidAt: DateTime.parse(json['paid_at'] as String),
    recordedBy: json['recorded_by'] as String,
    comment: json['comment'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    student: json['students'] != null
        ? Student.fromJson(json['students'] as Map<String, dynamic>)
        : null,
    paymentPlan: json['payment_plans'] != null
        ? PaymentPlan.fromJson(json['payment_plans'] as Map<String, dynamic>)
        : null,
    recordedByProfile: json['profiles'] != null
        ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'institution_id': institutionId,
    'student_id': studentId,
    'payment_plan_id': paymentPlanId,
    'amount': amount,
    'lessons_count': lessonsCount,
    'is_correction': isCorrection,
    'correction_reason': correctionReason,
    'paid_at': paidAt.toIso8601String(),
    'recorded_by': recordedBy,
    'comment': comment,
  };
}
```

---

## Вспомогательные типы

```dart
/// Период для статистики
enum StatisticsPeriod {
  day,
  week,
  month,
  custom;
  
  String get displayName {
    switch (this) {
      case StatisticsPeriod.day:
        return 'День';
      case StatisticsPeriod.week:
        return 'Неделя';
      case StatisticsPeriod.month:
        return 'Месяц';
      case StatisticsPeriod.custom:
        return 'Произвольный';
    }
  }
}

/// Стандартные длительности занятий
class LessonDurations {
  static const List<int> standard = [30, 45, 60, 90];
  static const int defaultDuration = 60;
}
```
