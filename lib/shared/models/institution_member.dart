import 'package:kabinet/shared/models/profile.dart';

/// Права доступа участника заведения
class MemberPermissions {
  final bool manageInstitution;
  final bool manageRooms;
  final bool manageMembers;
  final bool manageSubjects;
  final bool manageOwnStudents;
  final bool manageAllStudents;
  final bool manageGroups;
  final bool manageLessonTypes;
  final bool managePaymentPlans;
  final bool createLessons;
  final bool editOwnLessons;
  final bool editAllLessons;
  final bool deleteOwnLessons;
  final bool deleteAllLessons;
  final bool viewAllSchedule;
  final bool addPaymentsForOwnStudents;
  final bool addPaymentsForAllStudents;
  final bool managePayments;
  final bool viewPayments;
  final bool viewStatistics;
  final bool archiveData;
  final bool createBookings;

  const MemberPermissions({
    this.manageInstitution = false,
    this.manageRooms = false,
    this.manageMembers = false,
    this.manageSubjects = false,
    this.manageOwnStudents = true,
    this.manageAllStudents = false,
    this.manageGroups = true,
    this.manageLessonTypes = false,
    this.managePaymentPlans = false,
    this.createLessons = true,
    this.editOwnLessons = true,
    this.editAllLessons = false,
    this.deleteOwnLessons = true,
    this.deleteAllLessons = false,
    this.viewAllSchedule = true,
    this.addPaymentsForOwnStudents = true,
    this.addPaymentsForAllStudents = false,
    this.managePayments = false,
    this.viewPayments = true,
    this.viewStatistics = false,
    this.archiveData = false,
    this.createBookings = true,
  });

  /// Полные права (для владельца)
  factory MemberPermissions.owner() => const MemberPermissions(
        manageInstitution: true,
        manageRooms: true,
        manageMembers: true,
        manageSubjects: true,
        manageOwnStudents: true,
        manageAllStudents: true,
        manageGroups: true,
        manageLessonTypes: true,
        managePaymentPlans: true,
        createLessons: true,
        editOwnLessons: true,
        editAllLessons: true,
        deleteOwnLessons: true,
        deleteAllLessons: true,
        viewAllSchedule: true,
        addPaymentsForOwnStudents: true,
        addPaymentsForAllStudents: true,
        managePayments: true,
        viewPayments: true,
        viewStatistics: true,
        archiveData: true,
        createBookings: true,
      );

  /// Права по умолчанию для нового участника
  factory MemberPermissions.defaultTeacher() => const MemberPermissions();

  factory MemberPermissions.fromJson(Map<String, dynamic> json) =>
      MemberPermissions(
        manageInstitution: json['manage_institution'] as bool? ?? false,
        manageRooms: json['manage_rooms'] as bool? ?? false,
        manageMembers: json['manage_members'] as bool? ?? false,
        manageSubjects: json['manage_subjects'] as bool? ?? false,
        // Обратная совместимость: старое manage_students -> manageOwnStudents
        manageOwnStudents: json['manage_own_students'] as bool? ?? json['manage_students'] as bool? ?? false,
        manageAllStudents: json['manage_all_students'] as bool? ?? false,
        manageGroups: json['manage_groups'] as bool? ?? false,
        manageLessonTypes: json['manage_lesson_types'] as bool? ?? false,
        managePaymentPlans: json['manage_payment_plans'] as bool? ?? false,
        createLessons: json['create_lessons'] as bool? ?? true,
        editOwnLessons: json['edit_own_lessons'] as bool? ?? true,
        editAllLessons: json['edit_all_lessons'] as bool? ?? false,
        deleteOwnLessons: json['delete_own_lessons'] as bool? ?? json['delete_lessons'] as bool? ?? false,
        deleteAllLessons: json['delete_all_lessons'] as bool? ?? false,
        viewAllSchedule: json['view_all_schedule'] as bool? ?? true,
        // Обратная совместимость: старое manage_payments -> addPaymentsForAllStudents
        addPaymentsForOwnStudents: json['add_payments_for_own_students'] as bool? ?? true,
        addPaymentsForAllStudents: json['add_payments_for_all_students'] as bool? ?? json['manage_payments'] as bool? ?? false,
        managePayments: json['manage_payments'] as bool? ?? false,
        viewPayments: json['view_payments'] as bool? ?? false,
        viewStatistics: json['view_statistics'] as bool? ?? false,
        archiveData: json['archive_data'] as bool? ?? false,
        createBookings: json['create_bookings'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'manage_institution': manageInstitution,
        'manage_rooms': manageRooms,
        'manage_members': manageMembers,
        'manage_subjects': manageSubjects,
        'manage_own_students': manageOwnStudents,
        'manage_all_students': manageAllStudents,
        // Для обратной совместимости с RLS политикой в Supabase
        'manage_students': manageOwnStudents || manageAllStudents,
        'manage_groups': manageGroups,
        'manage_lesson_types': manageLessonTypes,
        'manage_payment_plans': managePaymentPlans,
        'create_lessons': createLessons,
        'edit_own_lessons': editOwnLessons,
        'edit_all_lessons': editAllLessons,
        'delete_own_lessons': deleteOwnLessons,
        'delete_all_lessons': deleteAllLessons,
        // Для обратной совместимости с RLS политикой в Supabase
        'delete_lessons': deleteOwnLessons || deleteAllLessons,
        'view_all_schedule': viewAllSchedule,
        'add_payments_for_own_students': addPaymentsForOwnStudents,
        'add_payments_for_all_students': addPaymentsForAllStudents,
        'manage_payments': managePayments,
        'view_payments': viewPayments,
        'view_statistics': viewStatistics,
        'archive_data': archiveData,
        'create_bookings': createBookings,
      };

  MemberPermissions copyWith({
    bool? manageInstitution,
    bool? manageRooms,
    bool? manageMembers,
    bool? manageSubjects,
    bool? manageOwnStudents,
    bool? manageAllStudents,
    bool? manageGroups,
    bool? manageLessonTypes,
    bool? managePaymentPlans,
    bool? createLessons,
    bool? editOwnLessons,
    bool? editAllLessons,
    bool? deleteOwnLessons,
    bool? deleteAllLessons,
    bool? viewAllSchedule,
    bool? addPaymentsForOwnStudents,
    bool? addPaymentsForAllStudents,
    bool? managePayments,
    bool? viewPayments,
    bool? viewStatistics,
    bool? archiveData,
    bool? createBookings,
  }) =>
      MemberPermissions(
        manageInstitution: manageInstitution ?? this.manageInstitution,
        manageRooms: manageRooms ?? this.manageRooms,
        manageMembers: manageMembers ?? this.manageMembers,
        manageSubjects: manageSubjects ?? this.manageSubjects,
        manageOwnStudents: manageOwnStudents ?? this.manageOwnStudents,
        manageAllStudents: manageAllStudents ?? this.manageAllStudents,
        manageGroups: manageGroups ?? this.manageGroups,
        manageLessonTypes: manageLessonTypes ?? this.manageLessonTypes,
        managePaymentPlans: managePaymentPlans ?? this.managePaymentPlans,
        createLessons: createLessons ?? this.createLessons,
        editOwnLessons: editOwnLessons ?? this.editOwnLessons,
        editAllLessons: editAllLessons ?? this.editAllLessons,
        deleteOwnLessons: deleteOwnLessons ?? this.deleteOwnLessons,
        deleteAllLessons: deleteAllLessons ?? this.deleteAllLessons,
        viewAllSchedule: viewAllSchedule ?? this.viewAllSchedule,
        addPaymentsForOwnStudents: addPaymentsForOwnStudents ?? this.addPaymentsForOwnStudents,
        addPaymentsForAllStudents: addPaymentsForAllStudents ?? this.addPaymentsForAllStudents,
        managePayments: managePayments ?? this.managePayments,
        viewPayments: viewPayments ?? this.viewPayments,
        viewStatistics: viewStatistics ?? this.viewStatistics,
        archiveData: archiveData ?? this.archiveData,
        createBookings: createBookings ?? this.createBookings,
      );
}

/// Участник заведения
class InstitutionMember {
  final String id;
  final String institutionId;
  final String userId;
  final String roleName;
  final MemberPermissions permissions;
  final bool isAdmin;
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
    this.isAdmin = false,
    required this.joinedAt,
    this.archivedAt,
    this.profile,
  });

  bool get isArchived => archivedAt != null;

  factory InstitutionMember.fromJson(Map<String, dynamic> json) =>
      InstitutionMember(
        id: json['id'] as String,
        institutionId: json['institution_id'] as String,
        userId: json['user_id'] as String,
        roleName: json['role_name'] as String,
        permissions: MemberPermissions.fromJson(
            json['permissions'] as Map<String, dynamic>),
        isAdmin: json['is_admin'] as bool? ?? false,
        joinedAt: DateTime.parse(json['joined_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        profile: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );

  /// Создать копию с профилем
  static InstitutionMember fromJsonWithProfile(
    InstitutionMember member,
    Map<String, dynamic> profileData,
  ) =>
      InstitutionMember(
        id: member.id,
        institutionId: member.institutionId,
        userId: member.userId,
        roleName: member.roleName,
        permissions: member.permissions,
        isAdmin: member.isAdmin,
        joinedAt: member.joinedAt,
        archivedAt: member.archivedAt,
        profile: Profile.fromJson(profileData),
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'user_id': userId,
        'role_name': roleName,
        'permissions': permissions.toJson(),
        'is_admin': isAdmin,
      };
}
