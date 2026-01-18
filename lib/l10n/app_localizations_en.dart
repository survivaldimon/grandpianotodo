// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Kabinet';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get archive => 'Archive';

  @override
  String get restore => 'Restore';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get search => 'Search';

  @override
  String get noData => 'No data';

  @override
  String get confirm => 'Confirm';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get apply => 'Apply';

  @override
  String get reset => 'Reset';

  @override
  String get all => 'All';

  @override
  String get select => 'Select';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get share => 'Share';

  @override
  String get more => 'More';

  @override
  String get less => 'Less';

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get optional => 'Optional';

  @override
  String get required => 'Required';

  @override
  String get or => 'or';

  @override
  String get and => 'and';

  @override
  String get from => 'from';

  @override
  String get to => 'to';

  @override
  String get tenge => 'KZT';

  @override
  String get login => 'Sign In';

  @override
  String get register => 'Sign Up';

  @override
  String get logout => 'Sign Out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get fullName => 'Full name';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get resetPasswordTitle => 'Password Recovery';

  @override
  String get resetPasswordMessage =>
      'Enter the email you used to register. We\'ll send you a link to reset your password.';

  @override
  String get resetPasswordSuccess => 'Email sent! Check your inbox.';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get hasAccount => 'Already have an account?';

  @override
  String get loginWithGoogle => 'Sign in with Google';

  @override
  String get loginWithApple => 'Sign in with Apple';

  @override
  String get newPassword => 'New password';

  @override
  String get setNewPassword => 'Set new password';

  @override
  String get setNewPasswordDescription => 'Set a new password';

  @override
  String get savePassword => 'Save password';

  @override
  String passwordChangeError(String error) {
    return 'Password change error: $error';
  }

  @override
  String get passwordChanged => 'Password changed successfully';

  @override
  String get registrationSuccess => 'Registration successful!';

  @override
  String get passwordRequirements =>
      'Min. 8 characters, uppercase letter, special character';

  @override
  String get institutions => 'Institutions';

  @override
  String get createInstitution => 'Create institution';

  @override
  String get joinInstitution => 'Join';

  @override
  String get institutionName => 'Institution name';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get institutionNameHint => 'For example: Music School No. 1';

  @override
  String get inviteCodeHint => 'For example: ABC12345';

  @override
  String get inviteCodeDescription =>
      'Enter the invite code that the institution administrator sent you';

  @override
  String joinedInstitution(String name) {
    return 'You joined \"$name\"';
  }

  @override
  String get owner => 'Owner';

  @override
  String get member => 'Member';

  @override
  String get admin => 'Administrator';

  @override
  String get teacher => 'Teacher';

  @override
  String get noInstitutions => 'No institutions';

  @override
  String get createOrJoin => 'Create new or join existing';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get rooms => 'Rooms';

  @override
  String get students => 'Students';

  @override
  String get payments => 'Payments';

  @override
  String get settings => 'Settings';

  @override
  String get statistics => 'Statistics';

  @override
  String get groups => 'Groups';

  @override
  String get schedule => 'Schedule';

  @override
  String get room => 'Room';

  @override
  String get roomName => 'Room name';

  @override
  String get roomNumber => 'Room number';

  @override
  String get addRoom => 'Add room';

  @override
  String get editRoom => 'Edit room';

  @override
  String get deleteRoom => 'Delete room';

  @override
  String get noRooms => 'No rooms';

  @override
  String get addRoomFirst => 'Add a room first';

  @override
  String get roomDeleted => 'Room deleted';

  @override
  String get roomUpdated => 'Room updated';

  @override
  String get roomCreated => 'Room created';

  @override
  String get roomColor => 'Room color';

  @override
  String get roomOccupied => 'Room is occupied at this time';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get lesson => 'Lesson';

  @override
  String get lessons => 'Lessons';

  @override
  String get newLesson => 'New lesson';

  @override
  String get editLesson => 'Edit lesson';

  @override
  String get deleteLesson => 'Delete lesson';

  @override
  String get lessonType => 'Lesson type';

  @override
  String get subject => 'Subject';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get startTime => 'Start time';

  @override
  String get endTime => 'End time';

  @override
  String get duration => 'Duration';

  @override
  String get minutes => 'min';

  @override
  String get comment => 'Comment';

  @override
  String get noLessons => 'No lessons';

  @override
  String get noLessonsToday => 'No lessons today';

  @override
  String get lessonsToday => 'Lessons today';

  @override
  String get nextLesson => 'Next lesson';

  @override
  String get selectDate => 'Select date';

  @override
  String get selectTime => 'Select time';

  @override
  String get selectRoom => 'Select room';

  @override
  String get selectStudent => 'Select student';

  @override
  String get selectSubject => 'Select subject';

  @override
  String get selectTeacher => 'Select teacher';

  @override
  String get selectLessonType => 'Select lesson type';

  @override
  String get repeatLesson => 'Repeat lesson';

  @override
  String get repeatWeekly => 'Every week';

  @override
  String get repeatCount => 'Number of repeats';

  @override
  String get quickAdd => 'Quick add';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get rescheduled => 'Rescheduled';

  @override
  String get markCompleted => 'Mark as completed';

  @override
  String get markCancelled => 'Cancel lesson';

  @override
  String get unmarkedLessons => 'Unmarked lessons';

  @override
  String get noUnmarkedLessons => 'No unmarked lessons';

  @override
  String get lessonCompleted => 'Lesson completed';

  @override
  String get lessonCancelled => 'Lesson cancelled';

  @override
  String get lessonDeleted => 'Lesson deleted';

  @override
  String get lessonCreated => 'Lesson created';

  @override
  String get lessonUpdated => 'Lesson updated';

  @override
  String get student => 'Student';

  @override
  String get studentName => 'Student name';

  @override
  String get phone => 'Phone';

  @override
  String get addStudent => 'Add student';

  @override
  String get editStudent => 'Edit student';

  @override
  String get deleteStudent => 'Delete student';

  @override
  String get archiveStudent => 'Archive student';

  @override
  String get unarchiveStudent => 'Unarchive';

  @override
  String get prepaidLessons => 'Prepaid lessons';

  @override
  String get debt => 'Debt';

  @override
  String get individualLesson => 'Individual';

  @override
  String get groupLesson => 'Group';

  @override
  String get noStudents => 'No students';

  @override
  String get addStudentFirst => 'Add your first student';

  @override
  String get studentDeleted => 'Student deleted';

  @override
  String get studentArchived => 'Student archived';

  @override
  String get studentUnarchived => 'Student unarchived';

  @override
  String get studentUpdated => 'Student updated';

  @override
  String get studentCreated => 'Student added';

  @override
  String get showArchived => 'Show archived';

  @override
  String get hideArchived => 'Hide archived';

  @override
  String get mergeStudents => 'Merge students';

  @override
  String get mergeWith => 'Merge with...';

  @override
  String get parentName => 'Parent name';

  @override
  String get parentPhone => 'Parent phone';

  @override
  String get notes => 'Notes';

  @override
  String get debtors => 'Debtors';

  @override
  String get noDebtors => 'No debtors';

  @override
  String get group => 'Group';

  @override
  String get groupName => 'Group name';

  @override
  String get addGroup => 'Add group';

  @override
  String get editGroup => 'Edit group';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String get archiveGroup => 'Archive group';

  @override
  String get members => 'Members';

  @override
  String get addMember => 'Add member';

  @override
  String get noGroups => 'No groups';

  @override
  String get groupDeleted => 'Group deleted';

  @override
  String get groupArchived => 'Group archived';

  @override
  String get groupUpdated => 'Group updated';

  @override
  String get groupCreated => 'Group created';

  @override
  String get selectStudents => 'Select students';

  @override
  String get minTwoStudents => 'Select at least 2 students';

  @override
  String get participants => 'Participants';

  @override
  String participantsCount(int count) {
    return 'PARTICIPANTS ($count)';
  }

  @override
  String get addParticipants => 'Add participants';

  @override
  String get selectStudentsForGroup => 'Select students for group';

  @override
  String get searchStudent => 'Search student...';

  @override
  String get createNewStudent => 'Create new student';

  @override
  String get allStudentsInGroup => 'All students already in group';

  @override
  String get noAvailableStudents => 'No available students';

  @override
  String get resetSearch => 'Reset search';

  @override
  String balanceColon(int count) {
    return 'Balance: $count';
  }

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String get removeStudentFromGroupQuestion => 'Remove from group?';

  @override
  String removeStudentFromGroupMessage(String name) {
    return 'Remove $name from group?';
  }

  @override
  String get studentAddedToGroup => 'Student added to group';

  @override
  String studentsAddedCount(int count) {
    return 'Students added: $count';
  }

  @override
  String get newStudent => 'New student';

  @override
  String studentCreatedAndSelected(String name) {
    return 'Student \"$name\" created and selected';
  }

  @override
  String get archiveGroupConfirmation => 'Archive group?';

  @override
  String archiveGroupMessage(String name) {
    return 'Group \"$name\" will be archived. You can restore it later.';
  }

  @override
  String get noParticipants => 'No participants';

  @override
  String get addStudentsToGroup => 'Add students to group';

  @override
  String get createFirstGroup => 'Create your first student group';

  @override
  String get createGroup => 'Create group';

  @override
  String get newGroup => 'New group';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String lessonsCountLabel(int count) {
    return 'Number of lessons:';
  }

  @override
  String selectedColon(int count) {
    return 'Selected: $count';
  }

  @override
  String addCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get payment => 'Payment';

  @override
  String get addPayment => 'Add payment';

  @override
  String get editPayment => 'Edit payment';

  @override
  String get deletePayment => 'Delete payment';

  @override
  String get amount => 'Amount';

  @override
  String get lessonsCount => 'Number of lessons';

  @override
  String get paymentPlan => 'Payment plan';

  @override
  String get paidAt => 'Payment date';

  @override
  String get correction => 'Correction';

  @override
  String get correctionReason => 'Correction reason';

  @override
  String get noPayments => 'No payments';

  @override
  String get paymentDeleted => 'Payment deleted';

  @override
  String get paymentUpdated => 'Payment updated';

  @override
  String get paymentCreated => 'Payment added';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get cash => 'Cash';

  @override
  String get card => 'Card';

  @override
  String get transfer => 'Transfer';

  @override
  String get todayPayments => 'Paid today';

  @override
  String get paymentHistory => 'Payment history';

  @override
  String get balanceTransfer => 'Balance transfer';

  @override
  String get balanceTransferComment => 'Transfer comment';

  @override
  String get filterStudents => 'Students';

  @override
  String get filterSubjects => 'Subjects';

  @override
  String get filterTeachers => 'Teachers';

  @override
  String get filterPlans => 'Plans';

  @override
  String get filterMethod => 'Method';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodQuarter => 'Quarter';

  @override
  String get periodYear => 'Year';

  @override
  String get periodCustom => 'Custom';

  @override
  String get total => 'Total:';

  @override
  String get totalOwnStudents => 'Total (your students):';

  @override
  String get noAccessToPayments => 'No access to view payments';

  @override
  String get noPaymentsForPeriod => 'No payments for this period';

  @override
  String get noPaymentsOwnForPeriod =>
      'No payments for your students in this period';

  @override
  String get noPaymentsWithFilters => 'No payments with selected filters';

  @override
  String get familySubscriptionOption => 'Group subscription';

  @override
  String get familySubscriptionDescription =>
      'One subscription for multiple students';

  @override
  String get selectParticipants => 'Select participants';

  @override
  String participantsOf(int count, int total) {
    return '$count of $total';
  }

  @override
  String get minTwoParticipants => 'Minimum 2 participants';

  @override
  String get minTwoParticipantsRequired =>
      'Select at least 2 participants for group subscription';

  @override
  String get mergeIntoCard => 'Merge into one card';

  @override
  String get mergeIntoCardDescription => 'Creates a group student card';

  @override
  String get groupCardName => 'Group card name';

  @override
  String get groupCardNameHint => 'For example: Petrov Family';

  @override
  String get selectStudentRequired => 'Select a student';

  @override
  String get selectStudentAndPlan => 'Select student and plan';

  @override
  String get addStudentsFirst => 'Add students first';

  @override
  String get customOption => 'Custom option';

  @override
  String get discount => 'Discount';

  @override
  String get discountSize => 'Discount amount';

  @override
  String wasPrice(String price) {
    return 'Was: $price ₸';
  }

  @override
  String totalPrice(String price) {
    return 'Total: $price ₸';
  }

  @override
  String get enterAmount => 'Enter amount';

  @override
  String get invalidAmount => 'Invalid amount';

  @override
  String get lessonsCountField => 'Lessons';

  @override
  String get enterValue => 'Enter';

  @override
  String get invalidNumber => 'Number';

  @override
  String get validityDays => 'Days';

  @override
  String get invalidValue => 'Invalid value';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String addPaymentWithAmount(String amount) {
    return 'Add payment $amount ₸';
  }

  @override
  String get cardMergedAndPaymentAdded => 'Card merged and payment added';

  @override
  String get groupSubscriptionAdded => 'Group subscription added';

  @override
  String get paymentAdded => 'Payment added';

  @override
  String deletePaymentConfirmation(int amount, int lessons) {
    return 'Payment of $amount ₸ will be deleted. Student balance will decrease by $lessons lessons.';
  }

  @override
  String get noEditPermission => 'No edit permission';

  @override
  String get canEditOwnStudentsOnly =>
      'You can only edit payments for your own students';

  @override
  String paymentFrom(String date) {
    return 'Payment from $date';
  }

  @override
  String get saveChanges => 'Save changes';

  @override
  String get deletePaymentButton => 'Delete payment';

  @override
  String get subscriptionMembers => 'Subscription members';

  @override
  String selectedCount(int count) {
    return 'Selected: $count';
  }

  @override
  String loadingError(String error) {
    return 'Loading error: $error';
  }

  @override
  String get noStudentsYet => 'No students';

  @override
  String discountNote(String amount) {
    return 'Discount: $amount ₸';
  }

  @override
  String get subscription => 'Subscription';

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get expiringSubscriptions => 'Expiring subscriptions';

  @override
  String get noSubscriptions => 'No subscriptions';

  @override
  String get lessonsRemaining => 'Lessons remaining';

  @override
  String get validUntil => 'Valid until';

  @override
  String get expired => 'Expired';

  @override
  String get active => 'Active';

  @override
  String get familySubscription => 'Family subscription';

  @override
  String get statusActive => 'Active';

  @override
  String get statusFrozen => 'Frozen';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusExhausted => 'Exhausted';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get hourOne => '1 hour';

  @override
  String get hourOneHalf => '1.5 hours';

  @override
  String hoursShort(int hours) {
    return '$hours h';
  }

  @override
  String hoursMinutesShort(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get currencyName => 'tenge';

  @override
  String get networkErrorMessage =>
      'Network error. Check your internet connection.';

  @override
  String get timeoutErrorMessage => 'Request timed out. Please try again.';

  @override
  String get sessionExpiredMessage => 'Session expired. Please sign in again.';

  @override
  String get errorOccurredMessage => 'An error occurred';

  @override
  String errorMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get profile => 'Profile';

  @override
  String get name => 'Name';

  @override
  String get registrationDate => 'Registration date';

  @override
  String get editName => 'Edit name';

  @override
  String get personName => 'Full name';

  @override
  String get personNameHint => 'John Smith';

  @override
  String get enterPersonName => 'Enter name';

  @override
  String get personNameUpdated => 'Name updated';

  @override
  String get subjects => 'Subjects';

  @override
  String get lessonTypes => 'Lesson types';

  @override
  String get paymentPlans => 'Payment Plans';

  @override
  String get teamMembers => 'Team members';

  @override
  String get inviteMembers => 'Invite member';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageRu => 'Russian';

  @override
  String get languageEn => 'English';

  @override
  String get account => 'Account';

  @override
  String get general => 'General';

  @override
  String get data => 'Data';

  @override
  String get workingHours => 'Working hours';

  @override
  String get workStart => 'Work start';

  @override
  String get workEnd => 'Work end';

  @override
  String get phoneCountry => 'Phone country code';

  @override
  String get changesSaved => 'Changes saved';

  @override
  String get inviteCodeCopied => 'Invite code copied';

  @override
  String get shareInviteCode => 'Share invite code';

  @override
  String get generateNewCode => 'Generate new code';

  @override
  String get permissions => 'Permissions';

  @override
  String get editPermissions => 'Edit permissions';

  @override
  String get removeMember => 'Remove member';

  @override
  String get leaveInstitution => 'Leave institution';

  @override
  String get booking => 'Booking';

  @override
  String get bookings => 'Bookings';

  @override
  String get addBooking => 'Add booking';

  @override
  String get deleteBooking => 'Delete booking';

  @override
  String get bookingDeleted => 'Booking deleted';

  @override
  String get bookingCreated => 'Booking created';

  @override
  String get permanentSchedule => 'Permanent schedule';

  @override
  String get oneTimeBooking => 'One-time booking';

  @override
  String get slot => 'Slot';

  @override
  String get slots => 'Slots';

  @override
  String get freeSlot => 'Free slot';

  @override
  String get occupiedSlot => 'Occupied slot';

  @override
  String get lessonSchedule => 'Permanent lesson';

  @override
  String get lessonSchedules => 'Permanent lessons';

  @override
  String get addLessonSchedule => 'Add permanent lesson';

  @override
  String get editLessonSchedule => 'Edit permanent lesson';

  @override
  String get deleteLessonSchedule => 'Delete permanent lesson';

  @override
  String get pauseLessonSchedule => 'Pause';

  @override
  String get resumeLessonSchedule => 'Resume';

  @override
  String get pauseUntil => 'Pause until';

  @override
  String get paused => 'Paused';

  @override
  String get dayOfWeek => 'Day of week';

  @override
  String get validFrom => 'Valid from';

  @override
  String get replaceRoom => 'Temporary room replacement';

  @override
  String get replaceUntil => 'Replace until';

  @override
  String get totalLessons => 'Total lessons';

  @override
  String get totalPayments => 'Total payments';

  @override
  String get totalStudents => 'Total students';

  @override
  String get period => 'Period';

  @override
  String get thisWeek => 'This week';

  @override
  String get thisMonth => 'This month';

  @override
  String get lastMonth => 'Last month';

  @override
  String get customPeriod => 'Custom period';

  @override
  String get income => 'Income';

  @override
  String get lessonsCompleted => 'Completed';

  @override
  String get lessonsCancelled => 'Cancelled';

  @override
  String get bySubject => 'By subject';

  @override
  String get byTeacher => 'By teacher';

  @override
  String get byStudent => 'By student';

  @override
  String get filters => 'Filters';

  @override
  String get filterBy => 'Filter by';

  @override
  String get sortBy => 'Sort by';

  @override
  String get dateRange => 'Date range';

  @override
  String get status => 'Status';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String get noResults => 'No results found';

  @override
  String get teachers => 'Teachers';

  @override
  String get monday => 'Monday';

  @override
  String get tuesday => 'Tuesday';

  @override
  String get wednesday => 'Wednesday';

  @override
  String get thursday => 'Thursday';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get sunday => 'Sunday';

  @override
  String get mondayShort => 'Mon';

  @override
  String get tuesdayShort => 'Tue';

  @override
  String get wednesdayShort => 'Wed';

  @override
  String get thursdayShort => 'Thu';

  @override
  String get fridayShort => 'Fri';

  @override
  String get saturdayShort => 'Sat';

  @override
  String get sundayShort => 'Sun';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get networkError => 'Network error. Check your connection.';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get weakPassword => 'Password is too weak';

  @override
  String get emailInUse => 'Email is already in use';

  @override
  String get invalidCredentials => 'Invalid email or password';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get minPasswordLength => 'Minimum 8 characters';

  @override
  String get passwordNeedsUppercase => 'At least one uppercase letter required';

  @override
  String get passwordNeedsSpecialChar =>
      'At least one special character required (!@#\$%^&*)';

  @override
  String get invalidPhoneNumber => 'Invalid phone number';

  @override
  String get enterPositiveNumber => 'Enter a positive number';

  @override
  String get enterPositiveInteger => 'Enter a positive integer';

  @override
  String get sessionExpired => 'Session expired. Please sign in again.';

  @override
  String get noServerConnection => 'No connection to server';

  @override
  String get errorOccurredTitle => 'An error occurred';

  @override
  String get timeoutError => 'Request timed out. Please try again.';

  @override
  String get noConnection => 'No connection to server';

  @override
  String get timeout => 'Request timed out. Please try again.';

  @override
  String get notFound => 'Not found';

  @override
  String get accessDenied => 'Access denied';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get confirmDelete => 'Confirm deletion';

  @override
  String get confirmArchive => 'Confirm archiving';

  @override
  String get confirmCancel => 'Confirm cancellation';

  @override
  String get confirmLogout => 'Sign out?';

  @override
  String get confirmLeave => 'Leave institution?';

  @override
  String get deleteConfirmation => 'Are you sure you want to delete?';

  @override
  String get archiveConfirmation => 'Are you sure you want to archive?';

  @override
  String get actionCannotBeUndone => 'This action cannot be undone';

  @override
  String deleteQuestion(String item) {
    return 'Delete $item?';
  }

  @override
  String archiveQuestion(String item) {
    return 'Archive $item?';
  }

  @override
  String lessonsCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons',
      one: '1 lesson',
      zero: 'no lessons',
    );
    return '$_temp0';
  }

  @override
  String studentsCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count students',
      one: '1 student',
      zero: 'no students',
    );
    return '$_temp0';
  }

  @override
  String paymentsCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
      one: '1 payment',
      zero: 'no payments',
    );
    return '$_temp0';
  }

  @override
  String daysCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: '0 days',
    );
    return '$_temp0';
  }

  @override
  String minutesCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
      zero: '0 minutes',
    );
    return '$_temp0';
  }

  @override
  String membersCountPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'no members',
    );
    return '$_temp0';
  }

  @override
  String prepaidLessonsBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prepaid lessons',
      one: '1 prepaid lesson',
      zero: 'No prepaid lessons',
    );
    return '$_temp0';
  }

  @override
  String lessonsRemainingPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lessons remaining',
      one: '1 lesson remaining',
      zero: 'No lessons remaining',
    );
    return '$_temp0';
  }

  @override
  String get colorPicker => 'Select color';

  @override
  String get selectColor => 'Select color';

  @override
  String get defaultColor => 'Default color';

  @override
  String get dateMissed => 'Date missed';

  @override
  String get slotPaused => 'Slot paused';

  @override
  String get exclusionAdded => 'Exclusion added';

  @override
  String get history => 'History';

  @override
  String get deleteFromHistory => 'Delete from history';

  @override
  String get noHistory => 'No history';

  @override
  String get sendLink => 'Send link';

  @override
  String get linkSent => 'Link sent';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get archiveInstitution => 'Archive institution';

  @override
  String get leaveInstitutionAction => 'Leave institution';

  @override
  String get institutionCanBeRestored => 'Institution can be restored later';

  @override
  String get youWillNoLongerBeMember => 'You will no longer be a member';

  @override
  String get archiveInstitutionQuestion => 'Archive institution?';

  @override
  String get leaveInstitutionQuestion => 'Leave institution?';

  @override
  String archiveInstitutionMessage(String name) {
    return 'Institution \"$name\" will be moved to archive. You can restore it later from the institutions list.';
  }

  @override
  String leaveInstitutionMessage(String name) {
    return 'Are you sure you want to leave \"$name\"? To return, you will need a new invite code.';
  }

  @override
  String get institutionArchived => 'Institution archived';

  @override
  String get institutionDeleted => 'Institution deleted';

  @override
  String get institutionDeletedMessage =>
      'This institution was deleted by the owner. You will be redirected to the main screen.';

  @override
  String get ok => 'OK';

  @override
  String get youLeftInstitution => 'You left the institution';

  @override
  String get generateNewCodeQuestion => 'Generate new code?';

  @override
  String get generateNewCodeMessage =>
      'The old code will stop working. Anyone who hasn\'t joined with the old code won\'t be able to do so.';

  @override
  String get generate => 'Generate';

  @override
  String newCodeGenerated(String code) {
    return 'New code: $code';
  }

  @override
  String get nameUpdated => 'Name updated';

  @override
  String get enterName => 'Enter name';

  @override
  String get workingHoursUpdated => 'Working hours updated';

  @override
  String get workingHoursDescription =>
      'This time will be displayed in the schedule grid';

  @override
  String get start => 'Start';

  @override
  String get end => 'End';

  @override
  String get byLocale => 'Based on device locale';

  @override
  String todayWithDate(String date) {
    return 'Today, $date';
  }

  @override
  String get noScheduledLessons => 'No scheduled lessons';

  @override
  String get urgent => 'Urgent';

  @override
  String get daysShort => 'd.';

  @override
  String get lessonPayment => 'Lesson payment';

  @override
  String saveError(String error) {
    return 'Save error: $error';
  }

  @override
  String get completeProfileSetup => 'Complete profile setup';

  @override
  String get selectColorAndSubjects => 'Select color and subjects';

  @override
  String get fillIn => 'Fill in';

  @override
  String get paid => 'Paid';

  @override
  String get archivedInstitutions => 'Archived institutions';

  @override
  String get archiveEmpty => 'Archive empty';

  @override
  String get restoreInstitutionQuestion => 'Restore institution?';

  @override
  String restoreInstitutionMessage(String name) {
    return 'Institution \"$name\" will be restored and appear in the main list.';
  }

  @override
  String get institutionRestored => 'Institution restored';

  @override
  String archivedOn(String date) {
    return 'Archived $date';
  }

  @override
  String get noMembers => 'No members';

  @override
  String get noName => 'No name';

  @override
  String get you => 'You';

  @override
  String get adminBadge => 'Admin';

  @override
  String get changeColor => 'Change color';

  @override
  String get colorUpdated => 'Color updated';

  @override
  String get colorReset => 'Color reset';

  @override
  String get directions => 'Subjects';

  @override
  String get changeRole => 'Change role';

  @override
  String get roleName => 'Role name';

  @override
  String get roleNameHint => 'For example: Teacher, Administrator';

  @override
  String get accessRights => 'Access rights';

  @override
  String get manageLessons => 'Manage lessons';

  @override
  String get transferOwnershipQuestion => 'Transfer ownership?';

  @override
  String get transferOwnershipWarning =>
      'You are about to transfer ownership rights to:';

  @override
  String get transferWarningTitle => 'Warning!';

  @override
  String get transferWarningPoints =>
      '• You will lose owner rights\n• New owner can delete the institution\n• This action cannot be undone by yourself';

  @override
  String ownershipTransferred(String name) {
    return 'Ownership transferred to $name';
  }

  @override
  String get removeMemberQuestion => 'Remove member?';

  @override
  String removeMemberConfirmation(String name) {
    return 'Are you sure you want to remove $name from the institution?';
  }

  @override
  String futureLessonsCount(int count) {
    return 'Future lessons: $count';
  }

  @override
  String get noFutureLessonsToManage => 'No future lessons to manage';

  @override
  String get deleteAllFutureLessons => 'Delete all future lessons';

  @override
  String get deleteAllFutureLessonsDescription =>
      'Lessons will be deleted without changing student balances';

  @override
  String get reassignTeacher => 'Reassign teacher';

  @override
  String get reassignTeacherDescription =>
      'Transfer all lessons to another teacher';

  @override
  String get deleteLessonsQuestion => 'Delete lessons?';

  @override
  String deleteLessonsCount(int count) {
    return '$count lessons of the teacher will be deleted:';
  }

  @override
  String get deleteLessonsWarning =>
      'Student subscription balances will not change.\nThis action cannot be undone.';

  @override
  String lessonsDeletedCount(int count) {
    return 'Lessons deleted: $count';
  }

  @override
  String get reassignLessons => 'Reassign lessons';

  @override
  String reassignLessonsFrom(int count, String name) {
    return '$count lessons from $name';
  }

  @override
  String get selectNewTeacher => 'Select new teacher:';

  @override
  String get noOtherTeachers => 'No other teachers';

  @override
  String get checkingConflicts => 'Checking conflicts...';

  @override
  String conflictsFound(int count) {
    return '$count conflicts found';
  }

  @override
  String get noConflictsFound => 'No conflicts found';

  @override
  String andMoreConflicts(int count) {
    return '...and $count more conflicts';
  }

  @override
  String get skipConflicts => 'Skip conflicts';

  @override
  String get reassign => 'Reassign';

  @override
  String conflictCheckError(String error) {
    return 'Check error: $error';
  }

  @override
  String get noLessonsToReassign => 'No lessons to reassign';

  @override
  String reassignedCount(int count) {
    return 'Lessons reassigned: $count';
  }

  @override
  String skippedConflicts(int count) {
    return 'skipped: $count';
  }

  @override
  String get noSubjectsAvailable => 'No subjects available';

  @override
  String get subjectsUpdated => 'Subjects updated';

  @override
  String errorWithDetails(String details) {
    return 'Error: $error';
  }

  @override
  String get newRoom => 'New room';

  @override
  String get editRoomTitle => 'Edit room';

  @override
  String get roomNumberRequired => 'Room number *';

  @override
  String get roomNumberHint => 'E.g.: 101';

  @override
  String get roomNameOptional => 'Name (optional)';

  @override
  String get roomNameHint => 'E.g.: Piano room';

  @override
  String get enterRoomNumber => 'Enter room number';

  @override
  String get fillRoomData => 'Fill in room data';

  @override
  String get changeRoomData => 'Change room details';

  @override
  String get createRoom => 'Create room';

  @override
  String roomWithNumber(String number) {
    return 'Room $number';
  }

  @override
  String roomCreatedMessage(String name) {
    return 'Room \"$name\" created';
  }

  @override
  String get deleteRoomQuestion => 'Delete room?';

  @override
  String deleteRoomMessage(String name) {
    return 'Room \"$name\" will be deleted. This action cannot be undone.';
  }

  @override
  String get myStudents => 'My';

  @override
  String get withDebt => 'With debt';

  @override
  String get searchByName => 'Search by name...';

  @override
  String get direction => 'Subject';

  @override
  String get activity => 'Activity';

  @override
  String get noStudentsByFilters => 'No students match the filters';

  @override
  String get tryDifferentQuery => 'Try a different search';

  @override
  String get archivedStudentsHere => 'Archived students will appear here';

  @override
  String get noStudentsWithDebt => 'No students with debt';

  @override
  String get allStudentsPositiveBalance =>
      'All students have a positive balance';

  @override
  String get noLinkedStudents => 'No linked students';

  @override
  String get noLinkedStudentsHint => 'No students are linked to you yet';

  @override
  String get addFirstStudent => 'Add your first student';

  @override
  String get noLessons7Days => 'No lessons for 7+ days';

  @override
  String get noLessons14Days => 'No lessons for 14+ days';

  @override
  String get noLessons30Days => 'No lessons for 30+ days';

  @override
  String get noLessons60Days => 'No lessons for 60+ days';

  @override
  String get groupNameHint => 'E.g.: Vocal group';

  @override
  String studentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count students',
      one: '1 student',
    );
    return '$_temp0';
  }

  @override
  String mergeCount(int count) {
    return 'Merge ($count)';
  }

  @override
  String get fillStudentData => 'Fill in student details';

  @override
  String get fullNameRequired => 'Full name *';

  @override
  String get fullNameHint => 'John Smith';

  @override
  String get enterStudentName => 'Enter student name';

  @override
  String get phoneHint => '+1 (555) 123-4567';

  @override
  String get noAvailableTeachers => 'No available teachers';

  @override
  String get additionalInfo => 'Additional information...';

  @override
  String get remainingLessons => 'Remaining lessons';

  @override
  String get fromOtherSchool => 'When transferring from another school';

  @override
  String get lessonsUnit => 'lessons';

  @override
  String get remainingLessonsHint => 'Deducted first, does not affect revenue';

  @override
  String get createStudent => 'Create student';

  @override
  String get selectRoomForSchedule => 'Select a room for the schedule';

  @override
  String get scheduleConflictsError =>
      'There are schedule conflicts. Change the time or room.';

  @override
  String get initialBalanceComment => 'Initial balance';

  @override
  String studentCreatedWithSchedule(String name) {
    return 'Student \"$name\" created with schedule';
  }

  @override
  String studentCreatedSimple(String name) {
    return 'Student \"$name\" created';
  }

  @override
  String get setupPermanentSchedule => 'Set up permanent schedule';

  @override
  String get selectDaysAndTime => 'Select days and lesson times';

  @override
  String get roomForLessons => 'Room for lessons';

  @override
  String get daysOfWeekLabel => 'Days of week';

  @override
  String get lessonTimeLabel => 'Lesson time';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get incorrect => 'Invalid';

  @override
  String get conflictTimeOccupied => 'Conflict! Time is occupied';

  @override
  String lessonsBalance(int count) {
    return '$count lessons';
  }

  @override
  String get noLessonTypes => 'No lesson types';

  @override
  String get addFirstLessonType => 'Add your first lesson type';

  @override
  String get addType => 'Add type';

  @override
  String get deleteLessonTypeQuestion => 'Delete lesson type?';

  @override
  String lessonTypeWillBeDeleted(String name) {
    return 'Type \"$name\" will be deleted';
  }

  @override
  String get lessonTypeDeleted => 'Lesson type deleted';

  @override
  String get newLessonType => 'New lesson type';

  @override
  String get fillLessonTypeData => 'Fill in type details';

  @override
  String get nameRequired => 'Name *';

  @override
  String get nameHintExample => 'E.g.: Individual';

  @override
  String get enterNameValidation => 'Enter name';

  @override
  String get other => 'Other';

  @override
  String get customDuration => 'Custom duration';

  @override
  String get defaultPrice => 'Default price';

  @override
  String get groupLessonSwitch => 'Group lesson';

  @override
  String get multipleStudents => 'Multiple students at once';

  @override
  String get oneStudent => 'One student';

  @override
  String get createType => 'Create type';

  @override
  String lessonTypeCreated(String name) {
    return 'Type \"$name\" created';
  }

  @override
  String get editLessonType => 'Edit type';

  @override
  String get changeLessonTypeData => 'Change lesson type details';

  @override
  String get durationValidationError =>
      'Duration must be between 5 and 480 minutes';

  @override
  String get color => 'Color';

  @override
  String get lessonTypeUpdated => 'Lesson type updated';

  @override
  String get scheduleTitle => 'Schedule';

  @override
  String roomWithNumberTitle(String number) {
    return 'Room $number';
  }

  @override
  String get filtersTooltip => 'Filters';

  @override
  String get addTooltip => 'Add';

  @override
  String get compactView => 'Compact';

  @override
  String get detailedView => 'Detailed';

  @override
  String get dayView => 'Day';

  @override
  String get weekView => 'Week';

  @override
  String get lessonDefault => 'Lesson';

  @override
  String get booked => 'Booked';

  @override
  String get studentDefault => 'Student';

  @override
  String get hour => 'Hour';

  @override
  String get deletedFromHistory => 'Delete from history';

  @override
  String get modify => 'Modify';

  @override
  String get cancelLesson => 'Cancel';

  @override
  String get skipThisDate => 'Skip this date';

  @override
  String get statusUpdateFailed => 'Failed to update status';

  @override
  String get lessonCompletedMessage => 'Lesson completed';

  @override
  String get lessonCancelledMessage => 'Lesson cancelled';

  @override
  String get skipDateTitle => 'Skip date';

  @override
  String skipDateMessage(String date) {
    return 'The lesson will not be displayed on $date.\n\nThis will not create an entry in lesson history.';
  }

  @override
  String get skip => 'Skip';

  @override
  String get dateSkipped => 'Date skipped';

  @override
  String get lessonDeducted => 'Lesson deducted';

  @override
  String get lessonReturned => 'Lesson returned';

  @override
  String get deleteLessonWithPayment =>
      'The lesson will be deleted from history.\nThe payment for the lesson will also be deleted.';

  @override
  String get deleteLessonWithBalance =>
      'The lesson will be deleted from history.\nThe deducted lesson will be returned to the student\'s balance.';

  @override
  String get deleteLessonSimple =>
      'The lesson will be completely deleted from history.';

  @override
  String get deleteLessonQuestion => 'Delete lesson?';

  @override
  String get lessonDeletedFromHistory => 'Lesson deleted from history';

  @override
  String get lessonPaymentType => 'Lesson payment';

  @override
  String get paymentAddedMessage => 'Payment added';

  @override
  String get paymentDeletedMessage => 'Payment deleted';

  @override
  String paymentDeleteError(String error) {
    return 'Payment deletion error: $error';
  }

  @override
  String cancelledLessonsCount(int count) {
    return 'Cancelled $count lessons';
  }

  @override
  String get cancelLessonTitle => 'Cancel lesson';

  @override
  String get cancelWithoutDeduction =>
      'The lesson will be cancelled and archived without deduction from balance';

  @override
  String get deductionWillBeReturned =>
      'The lesson deducted upon completion will be automatically returned to the balance.';

  @override
  String get deductFromBalance => 'Deduct lesson from balance';

  @override
  String get lessonWillBeDeducted => 'Lesson will be deducted from prepaid';

  @override
  String get whoToDeduct => 'Deduct lesson from:';

  @override
  String balanceLabel(int count) {
    return 'Balance: $count';
  }

  @override
  String seriesPartInfo(int count) {
    return 'This lesson is part of a series ($count lessons)';
  }

  @override
  String get onlyThis => 'Only this';

  @override
  String get thisAndFollowing => 'This and following';

  @override
  String get deductOnlyToday => 'Deduction will only apply to today\'s lesson';

  @override
  String get archiveWithoutDeduction =>
      'All series lessons will be archived without deduction';

  @override
  String cancelLessonsCount(int count) {
    return 'Cancel $count lessons';
  }

  @override
  String get seriesCancelled => 'Lesson series cancelled';

  @override
  String get cancelledWithDeduction =>
      'Lesson cancelled and deducted from balance';

  @override
  String get cancelledWithoutDeduction => 'Lesson cancelled';

  @override
  String get permanentSchedulePart =>
      'This lesson is part of a permanent schedule';

  @override
  String get thisAndAllFollowing => 'This and all following';

  @override
  String get participantsTitle => 'Participants';

  @override
  String get noParticipantsMessage => 'No participants';

  @override
  String get addGuestLabel => 'Add guest';

  @override
  String get payLabel => 'Pay';

  @override
  String get unknownStudent => 'Unknown';

  @override
  String get paymentTitle => 'Payment';

  @override
  String get removeFromLessonTooltip => 'Remove from lesson';

  @override
  String paymentRecorded(int count, String students) {
    return 'Payment recorded: $count $students';
  }

  @override
  String paymentError(String error) {
    return 'Payment error: $error';
  }

  @override
  String get studentSingular => 'student';

  @override
  String get studentFew => 'students';

  @override
  String get studentMany => 'students';

  @override
  String get removeParticipantQuestion => 'Remove participant?';

  @override
  String removeFromLessonMessage(String name) {
    return 'Remove $name from this lesson?';
  }

  @override
  String get removeFromLessonGeneric => 'Remove participant from this lesson?';

  @override
  String get remove => 'Remove';

  @override
  String get addGuestTitle => 'Add guest';

  @override
  String get allStudentsAdded => 'All students have already been added';

  @override
  String get editLessonTitle => 'Edit lesson';

  @override
  String get dateLabel => 'Date';

  @override
  String get timeLabel => 'Time';

  @override
  String get roomLabel => 'Room';

  @override
  String get groupLabel => 'Group';

  @override
  String get subjectLabel => 'Subject';

  @override
  String get lessonTypeLabel => 'Lesson type';

  @override
  String get notSelected => 'Not selected';

  @override
  String get saveChangesLabel => 'Save changes';

  @override
  String get minDurationError => 'Minimum lesson duration is 15 minutes';

  @override
  String get lessonUpdatedMessage => 'Lesson updated';

  @override
  String get noRepeat => 'No repeat';

  @override
  String get everyDay => 'Every day';

  @override
  String get everyWeek => 'Every week';

  @override
  String get byWeekdays => 'By weekdays';

  @override
  String get manualDates => 'Manual date selection';

  @override
  String get onlyThisLesson => 'Only this lesson';

  @override
  String get allSeriesLessons => 'All series lessons';

  @override
  String get selectedLessons => 'Selected';

  @override
  String roomAdded(String name) {
    return 'Room \"$name\" added';
  }

  @override
  String get newRoomTitle => 'New room';

  @override
  String get fillRoomDataMessage => 'Fill in room details';

  @override
  String get roomNumberLabel => 'Room number *';

  @override
  String get enterRoomNumberValidation => 'Enter room number';

  @override
  String get nameOptionalLabel => 'Name (optional)';

  @override
  String get nameOptionalHint => 'For example: Piano room';

  @override
  String get createRoomLabel => 'Create room';

  @override
  String get selectStudentTitle => 'Select student';

  @override
  String get noOwnStudents => 'You have no students';

  @override
  String showAllCount(int count) {
    return 'Show all ($count)';
  }

  @override
  String get otherStudents => 'Other students';

  @override
  String get hideLabel => 'Hide';

  @override
  String studentAddedMessage(String name) {
    return 'Student \"$name\" added';
  }

  @override
  String get newStudentTitle => 'New student';

  @override
  String get quickAddLabel => 'Quick add';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get enterStudentNameValidation => 'Enter student name';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get createStudentLabel => 'Create student';

  @override
  String subjectAddedMessage(String name) {
    return 'Subject \"$name\" added';
  }

  @override
  String get newSubjectTitle => 'New subject';

  @override
  String get addSubjectMessage => 'Add a subject for lessons';

  @override
  String get subjectNameLabel => 'Subject name';

  @override
  String get subjectNameHint => 'E.g.: Piano';

  @override
  String get enterSubjectNameValidation => 'Enter subject name';

  @override
  String get createSubjectLabel => 'Create subject';

  @override
  String get durationValidation => 'Duration must be between 5 and 480 minutes';

  @override
  String lessonTypeAddedMessage(String name) {
    return 'Lesson type \"$name\" added';
  }

  @override
  String get newLessonTypeTitle => 'New lesson type';

  @override
  String get configureLessonType => 'Configure lesson parameters';

  @override
  String get nameLabel => 'Name';

  @override
  String get lessonTypeNameHint => 'E.g.: Individual lesson';

  @override
  String get durationLabel => 'Duration';

  @override
  String get otherOption => 'Other';

  @override
  String get customDurationLabel => 'Custom duration';

  @override
  String get enterMinutes => 'Enter minutes';

  @override
  String get minutesSuffix => 'min';

  @override
  String get priceOptionalLabel => 'Price (optional)';

  @override
  String get priceHint => 'E.g.: 5000';

  @override
  String get groupLessonTitle => 'Group lesson';

  @override
  String get forMultipleStudents => 'For multiple students';

  @override
  String get createTypeLabel => 'Create type';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get resetLabel => 'Reset';

  @override
  String get teachersTitle => 'Teachers';

  @override
  String get lessonTypesTitle => 'Lesson types';

  @override
  String get directionsTitle => 'Subjects';

  @override
  String get applyFiltersLabel => 'Apply filters';

  @override
  String get showAllLabel => 'Show all';

  @override
  String get studentsTitle => 'Students';

  @override
  String get noStudentsMessage => 'No students';

  @override
  String get deletedStudent => 'Deleted';

  @override
  String get temporarilyShowAll => 'Temporarily showing all';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get allRooms => 'All rooms';

  @override
  String get defaultRoomsTitle => 'Default rooms';

  @override
  String get restoreRoomFilter => 'Restore room filter';

  @override
  String get showAllRooms => 'Show all rooms';

  @override
  String get noDataMessage => 'No data';

  @override
  String get selectDates => 'Select dates';

  @override
  String get doneLabel => 'Done';

  @override
  String get lessonTab => 'Lesson';

  @override
  String get bookingTab => 'Booking';

  @override
  String get noRoomsAvailable => 'No rooms available';

  @override
  String get dateRequired => 'Date *';

  @override
  String get timeRequired => 'Time *';

  @override
  String get roomsTitle => 'Rooms';

  @override
  String roomShort(String number) {
    return 'Room $number';
  }

  @override
  String get selectAtLeastOneRoom => 'Select at least one room';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get descriptionHint => 'Event, meeting, etc.';

  @override
  String get bookLabel => 'Book';

  @override
  String get studentTab => 'Student';

  @override
  String get groupTab => 'Group';

  @override
  String get studentRequired => 'Student *';

  @override
  String get selectStudentPlaceholder => 'Select a student';

  @override
  String get addStudentTooltip => 'Add student';

  @override
  String get groupRequired => 'Group *';

  @override
  String get noGroupsAvailable => 'No groups available';

  @override
  String get createGroupTooltip => 'Create group';

  @override
  String get teacherLabel => 'Teacher';

  @override
  String get addSubjectTooltip => 'Add subject';

  @override
  String get addLessonTypeTooltip => 'Add lesson type';

  @override
  String get repeatLabel => 'Repeat';

  @override
  String get selectDatesInCalendar => 'Select dates in calendar';

  @override
  String selectedDatesCount(int count) {
    return 'Selected: $count dates';
  }

  @override
  String get checkingConflictsMessage => 'Checking conflicts...';

  @override
  String willCreateLessons(int count) {
    return '$count lessons will be created';
  }

  @override
  String conflictsWillBeSkipped(int count) {
    return 'Conflicts: $count (will be skipped)';
  }

  @override
  String createSchedulesCount(int count) {
    return 'Create $count schedules';
  }

  @override
  String get createSchedule => 'Create schedule';

  @override
  String createLessonsCount(int count) {
    return 'Create $count lessons';
  }

  @override
  String get createLessonSingle => 'Create lesson';

  @override
  String get minBookingDuration => 'Minimum booking duration is 15 minutes';

  @override
  String get roomsBooked => 'Rooms booked';

  @override
  String get invalidTime => 'Invalid';

  @override
  String get minLessonDuration => 'Minimum lesson duration is 15 minutes';

  @override
  String permanentSchedulesCreated(int count) {
    return 'Created $count permanent schedules';
  }

  @override
  String get permanentScheduleCreated => 'Permanent schedule created';

  @override
  String get allDatesOccupied => 'All dates occupied';

  @override
  String lessonsCreatedWithSkipped(int created, int skipped) {
    return 'Created $created lessons (skipped: $skipped)';
  }

  @override
  String lessonsCreatedCount(int count) {
    return 'Created $count lessons';
  }

  @override
  String get groupLessonCreated => 'Group lesson created';

  @override
  String get lessonCreatedMessage => 'Lesson created';

  @override
  String get newGroupTitle => 'New group';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get createLabel => 'Create';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get deletingLabel => 'Deleting...';

  @override
  String get deleteBookingLabel => 'Delete booking';

  @override
  String get deleteBookingQuestion => 'Delete booking?';

  @override
  String get bookingWillBeDeleted =>
      'The booking will be deleted and rooms will be freed.';

  @override
  String get bookingDeletedMessage => 'Booking deleted';

  @override
  String get bookingDeleteError => 'Deletion error';

  @override
  String get bookRoomsTitle => 'Book rooms';

  @override
  String get selectRoomsLabel => 'Select rooms';

  @override
  String get selectAtLeastOneRoomMessage => 'Select at least one room';

  @override
  String get dateTitle => 'Date';

  @override
  String get startTitle => 'Start';

  @override
  String get endTitle => 'End';

  @override
  String get descriptionOptionalLabel => 'Description (optional)';

  @override
  String get descriptionExampleHint => 'E.g.: Rehearsal, Event';

  @override
  String get bookingError => 'Booking error';

  @override
  String get permanentScheduleTitle => 'Permanent schedule';

  @override
  String get notSpecified => 'Not specified';

  @override
  String temporaryRoomReplacement(String room, String date) {
    return 'Temporarily in room $room until $date';
  }

  @override
  String createLessonOnDate(String date) {
    return 'Create lesson on $date';
  }

  @override
  String get createLessonsForPeriod => 'Create lessons for period';

  @override
  String get createMultipleLessons => 'Create multiple lessons from this slot';

  @override
  String get addException => 'Add exception';

  @override
  String get slotWontWorkOnDate =>
      'Slot will not be active on the selected date';

  @override
  String get pauseSlot => 'Pause';

  @override
  String get temporarilyDeactivate => 'Temporarily deactivate';

  @override
  String get resumeSlot => 'Resume';

  @override
  String pausedUntilDate(String date) {
    return 'Paused until $date';
  }

  @override
  String get indefinitePause => 'Indefinite pause';

  @override
  String get deactivate => 'Deactivate';

  @override
  String get completelyDisableSlot => 'Completely disable slot';

  @override
  String get addExceptionTitle => 'Add exception';

  @override
  String slotWontWorkMessage(String date) {
    return 'Slot will not be active on $date.\n\nThis will allow creating another lesson at this time.';
  }

  @override
  String get addLabel => 'Add';

  @override
  String get exceptionAdded => 'Exception added';

  @override
  String get pauseUntilLabel => 'Pause until';

  @override
  String slotPausedUntil(String date) {
    return 'Slot paused until $date';
  }

  @override
  String get slotResumed => 'Slot resumed';

  @override
  String get deactivateSlotTitle => 'Deactivate slot';

  @override
  String get deactivateSlotMessage =>
      'The slot will be completely disabled and will not be displayed in the schedule.\n\nYou can reactivate it in the student card.';

  @override
  String get slotDeactivated => 'Slot deactivated';

  @override
  String get createLessonsForPeriodTitle => 'Create lessons for period';

  @override
  String studentLabel(String name) {
    return 'Student: $name';
  }

  @override
  String get fromDateLabel => 'From date';

  @override
  String get toDateLabel => 'To date';

  @override
  String willBeCreated(int count) {
    return 'Will be created: $count lessons';
  }

  @override
  String get creatingLabel => 'Creating...';

  @override
  String get createLessonsLabel => 'Create lessons';

  @override
  String get noDatesToCreate => 'No dates to create';

  @override
  String get roomNotSpecified => 'Room not specified';

  @override
  String lessonsCreatedMessage(int count) {
    return 'Created $count lessons';
  }

  @override
  String seriesLoadError(String error) {
    return 'Series loading error: $error';
  }

  @override
  String get editSeriesTitle => 'Edit series';

  @override
  String get savingLabel => 'Saving...';

  @override
  String get applyChangesLabel => 'Apply changes';

  @override
  String get changesScope => 'Changes scope';

  @override
  String get byWeekdaysLabel => 'By weekdays';

  @override
  String get quantityLabel => 'Number of lessons:';

  @override
  String get allLabel => 'All';

  @override
  String seriesLessons(int count) {
    return 'Series lessons ($count)';
  }

  @override
  String get changesTitle => 'Changes';

  @override
  String willBeChanged(int count) {
    return 'Will be changed: $count lessons';
  }

  @override
  String get currentLabel => 'current';

  @override
  String get noLessonsToUpdate => 'No lessons to update (all have conflicts)';

  @override
  String lessonsUpdatedWithSkipped(int updated, int skipped) {
    return 'Updated $updated lessons (skipped: $skipped)';
  }

  @override
  String lessonsUpdatedCount(int count) {
    return 'Updated $count lessons';
  }

  @override
  String get memberDataError => 'Failed to get member data';

  @override
  String get showingAllRooms => 'Showing all rooms';

  @override
  String roomsSelectedCount(int count) {
    return 'Rooms selected: $count';
  }

  @override
  String get whichRoomsDoYouUse => 'Which rooms do you use?';

  @override
  String get onlySelectedRoomsShown =>
      'Only selected rooms will be displayed in the schedule. You can change this setting at any time through the filter menu.';

  @override
  String get selectDefaultRooms =>
      'Select rooms that will be displayed in the schedule by default.';

  @override
  String get skipLabel => 'Skip';

  @override
  String saveWithCount(int count) {
    return 'Save ($count)';
  }

  @override
  String get virtualLesson => 'Virtual lesson';

  @override
  String completeOnDate(String date) {
    return 'Complete lesson on $date';
  }

  @override
  String get createRealCompleted =>
      'Create a real lesson with status \"Completed\"';

  @override
  String cancelOnDate(String date) {
    return 'Cancel lesson on $date';
  }

  @override
  String get createRealCancelled =>
      'Create a real lesson with status \"Cancelled\"';

  @override
  String get skipThisDateLabel => 'Skip this date';

  @override
  String get addExceptionWithoutLesson =>
      'Add exception without creating lesson';

  @override
  String get pauseSchedule => 'Pause schedule';

  @override
  String get temporarilyDeactivateSchedule => 'Temporarily deactivate';

  @override
  String get resumeSchedule => 'Resume schedule';

  @override
  String get completelyDisableSchedule => 'Completely disable schedule';

  @override
  String get schedulePaused => 'Schedule paused';

  @override
  String get scheduleResumed => 'Schedule resumed';

  @override
  String get deactivateScheduleTitle => 'Deactivate schedule';

  @override
  String get deactivateScheduleMessage =>
      'The schedule will be completely disabled. This action can be undone.';

  @override
  String get scheduleDeactivated => 'Schedule deactivated';

  @override
  String get deductedFromBalance => 'Deducted from balance';

  @override
  String get lessonDeductedFromBalance =>
      'Lesson deducted from student\'s balance';

  @override
  String get lessonNotDeducted => 'Lesson not deducted from balance';

  @override
  String get completedLabel => 'Completed';

  @override
  String get paidLabel => 'Paid';

  @override
  String get costLabel => 'Cost';

  @override
  String get repeatSeriesLabel => 'Repeat';

  @override
  String get yesLabel => 'Yes';

  @override
  String get typeLabel => 'Type';

  @override
  String get statusUpdateError => 'Failed to update status';

  @override
  String get deductFromBalanceTitle => 'Deduct lesson from balance';

  @override
  String get addGuest => 'Add guest';

  @override
  String get pay => 'Pay';

  @override
  String get defaultRooms => 'Default rooms';

  @override
  String get book => 'Book';

  @override
  String get deleteBookingMessage =>
      'Booking will be deleted and rooms will be freed.';

  @override
  String get endLabel => 'End';

  @override
  String get createMultipleLessonsFromSlot =>
      'Create multiple lessons from this slot';

  @override
  String get slotWillNotWorkOnDate => 'Slot will not work on selected date';

  @override
  String get pause => 'Pause';

  @override
  String get temporarilyDeactivateSlot => 'Temporarily deactivate slot';

  @override
  String get resume => 'Resume';

  @override
  String get deactivateSlot => 'Deactivate slot';

  @override
  String get oneMonth => '1 month';

  @override
  String get threeMonths => '3 months';

  @override
  String get sixMonths => '6 months';

  @override
  String get oneYear => '1 year';

  @override
  String get createCompletedLesson =>
      'Create real lesson with status \"Completed\"';

  @override
  String get createCancelledLesson =>
      'Create real lesson with status \"Cancelled\"';

  @override
  String get deactivateSchedule => 'Deactivate schedule';

  @override
  String get scheduleWillBeDisabled =>
      'Schedule will be completely disabled. This action can be undone.';

  @override
  String get permissionsSaved => 'Permissions saved';

  @override
  String get permissionSectionInstitution => 'Institution Management';

  @override
  String get permissionManageInstitution => 'Edit institution';

  @override
  String get permissionManageInstitutionDesc => 'Change name, settings';

  @override
  String get permissionManageMembers => 'Manage members';

  @override
  String get permissionManageMembersDesc => 'Add, remove, change permissions';

  @override
  String get permissionArchiveData => 'Archive data';

  @override
  String get permissionArchiveDataDesc => 'Archive students, groups';

  @override
  String get permissionSectionReferences => 'References';

  @override
  String get permissionManageRooms => 'Manage rooms';

  @override
  String get permissionManageRoomsDesc => 'Create, edit, delete';

  @override
  String get permissionManageSubjects => 'Manage subjects';

  @override
  String get permissionManageSubjectsDesc => 'Create, edit, delete';

  @override
  String get permissionManageLessonTypes => 'Manage lesson types';

  @override
  String get permissionManageLessonTypesDesc => 'Create, edit, delete';

  @override
  String get permissionManagePaymentPlans => 'Manage payment plans';

  @override
  String get permissionManagePaymentPlansDesc => 'Create, edit, delete';

  @override
  String get permissionSectionStudents => 'Students & Groups';

  @override
  String get permissionManageOwnStudents => 'Manage own students';

  @override
  String get permissionManageOwnStudentsDesc => 'Create, edit own students';

  @override
  String get permissionManageAllStudents => 'Manage all students';

  @override
  String get permissionManageAllStudentsDesc =>
      'Manage other teachers\' students';

  @override
  String get permissionManageGroups => 'Manage groups';

  @override
  String get permissionManageGroupsDesc => 'Create, edit groups';

  @override
  String get permissionSectionSchedule => 'Schedule';

  @override
  String get permissionViewAllSchedule => 'View all schedule';

  @override
  String get permissionViewAllScheduleDesc => 'View other teachers\' lessons';

  @override
  String get permissionCreateLessons => 'Create lessons';

  @override
  String get permissionCreateLessonsDesc => 'Add new lessons to schedule';

  @override
  String get permissionEditOwnLessons => 'Edit own lessons';

  @override
  String get permissionEditOwnLessonsDesc => 'Modify own lessons';

  @override
  String get permissionEditAllLessons => 'Edit all lessons';

  @override
  String get permissionEditAllLessonsDesc => 'Modify other teachers\' lessons';

  @override
  String get permissionDeleteOwnLessons => 'Delete own lessons';

  @override
  String get permissionDeleteOwnLessonsDesc =>
      'Remove own lessons from schedule';

  @override
  String get permissionDeleteAllLessons => 'Delete all lessons';

  @override
  String get permissionDeleteAllLessonsDesc =>
      'Remove other teachers\' lessons';

  @override
  String get permissionSectionFinance => 'Finance';

  @override
  String get permissionViewOwnStudentsPayments =>
      'View own students\' payments';

  @override
  String get permissionViewOwnStudentsPaymentsDesc =>
      'View payments from own students';

  @override
  String get permissionViewAllPayments => 'View all payments';

  @override
  String get permissionViewAllPaymentsDesc => 'View payments from all students';

  @override
  String get permissionAddPaymentsForOwnStudents =>
      'Add payments for own students';

  @override
  String get permissionAddPaymentsForOwnStudentsDesc =>
      'Accept payments from own students';

  @override
  String get permissionAddPaymentsForAllStudents =>
      'Add payments for all students';

  @override
  String get permissionAddPaymentsForAllStudentsDesc =>
      'Accept payments from any students';

  @override
  String get permissionManageOwnStudentsPayments =>
      'Edit own students\' payments';

  @override
  String get permissionManageOwnStudentsPaymentsDesc =>
      'Modify and delete own students\' payments';

  @override
  String get permissionManageAllPayments => 'Edit all payments';

  @override
  String get permissionManageAllPaymentsDesc =>
      'Modify and delete any payments';

  @override
  String get permissionViewStatistics => 'View statistics';

  @override
  String get permissionViewStatisticsDesc => 'Access statistics section';

  @override
  String get statusSection => 'STATUS';

  @override
  String get adminHasAllPermissions => 'Administrator';

  @override
  String get grantFullPermissions => 'Grant all permissions';

  @override
  String get allPermissionsEnabledForAdmin => 'Enabled for administrator';

  @override
  String get welcome => 'Welcome!';

  @override
  String get selectColorForLessons =>
      'Choose a color for your\nlessons in the schedule';

  @override
  String get yourDirections => 'Your directions';

  @override
  String get selectSubjectsYouTeach => 'Select subjects you teach';

  @override
  String get noSubjectsInInstitution => 'No subjects in institution yet';

  @override
  String get ownerCanAddInSettings => 'The owner can add them in settings';

  @override
  String get noPaymentPlans => 'No payment plans';

  @override
  String get addFirstPaymentPlan => 'Add your first payment plan';

  @override
  String get addPlan => 'Add plan';

  @override
  String get addPaymentPlan => 'Add plan';

  @override
  String get paymentPlanNameHint => 'E.g.: 8-lesson subscription';

  @override
  String get enterNameField => 'Enter name';

  @override
  String get lessonsRequired => 'Lessons *';

  @override
  String get invalidValueError => 'Invalid value';

  @override
  String get createPaymentPlan => 'Create plan';

  @override
  String get deletePaymentPlanQuestion => 'Delete payment plan?';

  @override
  String paymentPlanWillBeDeleted(String name) {
    return 'Plan \"$name\" will be deleted';
  }

  @override
  String get paymentPlanDeleted => 'Payment plan deleted';

  @override
  String paymentPlanCreated(String name) {
    return 'Plan \"$name\" created';
  }

  @override
  String get newPaymentPlan => 'New payment plan';

  @override
  String get fillPaymentPlanData => 'Fill in plan details';

  @override
  String get planNameHint => 'E.g.: 8-lesson subscription';

  @override
  String get lessonsCountRequired => 'Lessons *';

  @override
  String get priceRequired => 'Price *';

  @override
  String get validityDaysRequired => 'Validity (days) *';

  @override
  String get enterValidityDays => 'Enter validity';

  @override
  String get createPlan => 'Create plan';

  @override
  String get paymentPlanUpdated => 'Payment plan updated';

  @override
  String get editPaymentPlan => 'Edit payment plan';

  @override
  String get changePaymentPlanData => 'Change plan details';

  @override
  String pricePerLesson(String price) {
    return '$price ₸/lesson';
  }

  @override
  String validityDaysShort(int days) {
    return '$days d.';
  }

  @override
  String get noSubjects => 'No subjects';

  @override
  String get addFirstSubject => 'Add your first subject';

  @override
  String get deleteSubjectQuestion => 'Delete subject?';

  @override
  String subjectWillBeDeleted(String name) {
    return 'Subject \"$name\" will be deleted';
  }

  @override
  String get subjectDeleted => 'Subject deleted';

  @override
  String subjectCreated(String name) {
    return 'Subject \"$name\" created';
  }

  @override
  String get newSubject => 'New subject';

  @override
  String get fillSubjectData => 'Enter subject name';

  @override
  String get addSubject => 'Add subject';

  @override
  String get createSubject => 'Create subject';

  @override
  String get enterSubjectName => 'Enter subject name';

  @override
  String get subjectNameRequired => 'Name *';

  @override
  String get subjectUpdated => 'Subject updated';

  @override
  String get editSubject => 'Edit subject';

  @override
  String get changeSubjectData => 'Change subject details';

  @override
  String get noAccessToStatistics => 'No access to statistics';

  @override
  String get statisticsNoAccess => 'No access to statistics';

  @override
  String get statsTabGeneral => 'General';

  @override
  String get statsTotal => 'Lessons';

  @override
  String get statsFinances => 'Finances';

  @override
  String get statsAvgLessonApprox => '≈';

  @override
  String get statsAvgLesson => 'Avg. lesson';

  @override
  String get statsDiscounts => 'Discounts';

  @override
  String statsPaidLessonsOf(int paid, int total) {
    return '$paid of $total';
  }

  @override
  String statsPaymentsWithDiscount(int count) {
    return '$count with discount';
  }

  @override
  String get statsWorkload => 'Workload';

  @override
  String get statsLessonHours => 'Hours of lessons';

  @override
  String get statsActiveStudents => 'Active students';

  @override
  String get statsPaymentMethods => 'Payment methods';

  @override
  String statsCardPayments(int count, String percent) {
    return 'Card ($count) — $percent%';
  }

  @override
  String statsCashPayments(int count, String percent) {
    return 'Cash ($count) — $percent%';
  }

  @override
  String get statsAvgLessonShort => 'Avg:';

  @override
  String get statsLessonStats => 'Lesson statistics';

  @override
  String get contactOwner => 'Contact the institution owner';

  @override
  String get tabGeneral => 'General';

  @override
  String get tabSubjects => 'Subjects';

  @override
  String get tabTeachers => 'Teachers';

  @override
  String get tabStudents => 'Students';

  @override
  String get tabPlans => 'Plans';

  @override
  String get lessonsTotal => 'Total';

  @override
  String get lessonsScheduled => 'Scheduled';

  @override
  String get paymentsLabel => 'Payments';

  @override
  String get avgLesson => 'Avg. lesson';

  @override
  String get discounts => 'Discounts';

  @override
  String get workload => 'Workload';

  @override
  String get hoursOfLessons => 'Hours of lessons';

  @override
  String get activeStudentsCount => 'Active students';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get noDataForPeriod => 'No data for period';

  @override
  String get lessonStatistics => 'Lesson statistics';

  @override
  String get cancellationRate => 'Cancellation rate';

  @override
  String get topByLessons => 'Top by lessons';

  @override
  String get lessonsShort => 'les.';

  @override
  String get byStudents => 'By students';

  @override
  String get purchases => 'Purchases';

  @override
  String get sumLabel => 'Sum';

  @override
  String get avgLessonCost => 'Average lesson cost';

  @override
  String get paymentsWithDiscount => 'Payments with discount';

  @override
  String get discountSum => 'Discount sum';

  @override
  String get byPlans => 'By plans';

  @override
  String get purchasesShort => 'purch.';

  @override
  String cancellationRatePercent(String rate) {
    return 'Cancellation rate: $rate%';
  }

  @override
  String get paymentMethods => 'Payment methods';

  @override
  String cardPaymentsCount(int count) {
    return 'Card ($count)';
  }

  @override
  String cashPaymentsCount(int count) {
    return 'Cash ($count)';
  }

  @override
  String lessonsCountShort(int count) {
    return '$count les.';
  }

  @override
  String mergeStudentsCount(int count) {
    return 'Merge $count students';
  }

  @override
  String mergeStudentsTitle(int count) {
    return 'Merge $count students';
  }

  @override
  String get mergeStudentsWarning =>
      'A new card will be created. Original cards will be archived.';

  @override
  String get fromLegacyBalance => 'From legacy';

  @override
  String cardCreatedWithName(String name) {
    return 'Card \"$name\" created';
  }

  @override
  String get mergeWarning =>
      'A new card will be created. Original cards will be archived.';

  @override
  String get studentsToMerge => 'Students to merge';

  @override
  String get totalBalance => 'Total balance';

  @override
  String get fromLegacy => 'From legacy';

  @override
  String get newCardData => 'New card data';

  @override
  String get merge => 'Merge';

  @override
  String cardCreated(String name) {
    return 'Card \"$name\" created';
  }

  @override
  String get mergeError => 'Error while merging';

  @override
  String get lessonTime => 'Lesson time';

  @override
  String get invalid => 'Invalid';

  @override
  String durationFormat(int hours, int mins) {
    return '${hours}h ${mins}m';
  }

  @override
  String hoursOnly(int hours) {
    return '${hours}h';
  }

  @override
  String minutesOnly(int mins) {
    return '${mins}m';
  }

  @override
  String get quickSelect => 'Quick select';

  @override
  String get palette => 'Palette';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get studentInArchive => 'Student is archived';

  @override
  String get unarchiveToCreateLessons => 'Unarchive to create lessons';

  @override
  String get contactInfo => 'Contact information';

  @override
  String get noPhone => 'Phone not specified';

  @override
  String get phoneCopied => 'Phone copied';

  @override
  String get lessonStatisticsTitle => 'Lesson statistics';

  @override
  String get noLessonsYet => 'No lessons yet';

  @override
  String get balance => 'Balance';

  @override
  String get subscriptionsSection => 'Subscriptions';

  @override
  String get noActiveSubscriptions => 'No active subscriptions';

  @override
  String get paymentsSection => 'Payments';

  @override
  String get noPaymentsHistory => 'No payment history';

  @override
  String showMoreCount(int count) {
    return 'Show more ($count)';
  }

  @override
  String get permanentScheduleSection => 'Permanent schedule';

  @override
  String get noPermanentSchedule => 'No permanent schedule';

  @override
  String get addScheduleSlot => 'Add slot';

  @override
  String get createLessonsFromSchedule => 'Create lessons from schedule';

  @override
  String get repeatGroupsSection => 'Lesson series';

  @override
  String get noRepeatGroups => 'No lesson series';

  @override
  String get lessonHistorySection => 'Lesson history';

  @override
  String get manageLessonsTitle => 'Manage lessons';

  @override
  String get archivedSection => 'Archived';

  @override
  String get archived => 'Archived';

  @override
  String inRoom(String room) {
    return 'in room $room';
  }

  @override
  String temporaryRoomUntil(String room, String date) {
    return 'Temporarily $room until $date';
  }

  @override
  String schedulePausedUntil(String date) {
    return 'Paused until $date';
  }

  @override
  String get resumeScheduleAction => 'Resume';

  @override
  String get pauseScheduleAction => 'Pause';

  @override
  String get clearReplacementRoom => 'Clear room replacement';

  @override
  String get temporaryRoomReplacementAction => 'Temporary room replacement';

  @override
  String get archiveSchedule => 'Archive';

  @override
  String get unarchiveSchedule => 'Unarchive';

  @override
  String get deleteScheduleAction => 'Delete';

  @override
  String get scheduleResumedMessage => 'Schedule resumed';

  @override
  String get pauseScheduleTitle => 'Pause schedule';

  @override
  String get pauseScheduleUntilQuestion => 'Until which date to pause?';

  @override
  String get resumeDate => 'Resume date';

  @override
  String get selectDatePlaceholder => 'Select date';

  @override
  String get pauseAction => 'Pause';

  @override
  String schedulePausedUntilMessage(String date) {
    return 'Schedule paused until $date';
  }

  @override
  String get replacementRoomCleared => 'Room replacement cleared';

  @override
  String get temporaryRoomReplacementTitle => 'Temporary room replacement';

  @override
  String get untilDateLabel => 'Until date';

  @override
  String get replacementRoomSet => 'Room replacement set';

  @override
  String get archiveScheduleQuestion => 'Archive schedule?';

  @override
  String get archiveScheduleMessage =>
      'Slot will be moved to archive. You can unarchive it later.';

  @override
  String get scheduleArchivedMessage => 'Schedule archived';

  @override
  String get scheduleUnarchivedMessage => 'Schedule unarchived';

  @override
  String get deleteScheduleQuestion => 'Delete schedule?';

  @override
  String get deleteScheduleMessage =>
      'This slot will be deleted forever. This action cannot be undone.';

  @override
  String get scheduleDeletedMessage => 'Schedule deleted';

  @override
  String get editScheduleTitle => 'Edit schedule';

  @override
  String get startTimeLabel => 'Start time';

  @override
  String get endTimeLabel => 'End time';

  @override
  String get roomFieldLabel => 'Room';

  @override
  String get scheduleUpdatedMessage => 'Schedule updated';

  @override
  String get scheduleUpdateError => 'Update error (possible time conflict)';

  @override
  String lessonsInSeries(int count) {
    return '$count lessons in series';
  }

  @override
  String seriesStartDate(String date) {
    return 'Start: $date';
  }

  @override
  String get editAction => 'Edit';

  @override
  String get deleteSeriesAction => 'Delete series';

  @override
  String get editSeriesSheetTitle => 'Edit series';

  @override
  String get deleteSeriesQuestion => 'Delete series?';

  @override
  String deleteSeriesMessage(int count) {
    return '$count lessons will be deleted from schedule. This action cannot be undone.';
  }

  @override
  String get seriesDeleted => 'Series deleted';

  @override
  String get deletionError => 'Deletion error';

  @override
  String get seriesUpdated => 'Series updated';

  @override
  String get updateError => 'Update error';

  @override
  String get createLessonsFromScheduleTitle => 'Create lessons from schedule';

  @override
  String get createLessonsDescription =>
      'Lessons will be created based on the student\'s permanent schedule.';

  @override
  String get fromDateField => 'From date';

  @override
  String get toDateField => 'To date';

  @override
  String get oneWeek => '1 week';

  @override
  String get twoWeeks => '2 weeks';

  @override
  String get checkConflicts => 'Check conflicts';

  @override
  String get noConflictsMessage => 'No conflicts found';

  @override
  String conflictsFoundCount(int count) {
    return 'Conflicts found: $count';
  }

  @override
  String get datesWillBeSkipped => 'These dates will be skipped:';

  @override
  String andMoreCount(int count) {
    return '...and $count more';
  }

  @override
  String get createLessonsAction => 'Create lessons';

  @override
  String get creatingLessons => 'Creating...';

  @override
  String lessonsCreatedSkipped(int success, int skipped) {
    return 'Lessons created: $success, skipped: $skipped';
  }

  @override
  String get addPermanentScheduleTitle => 'Add permanent schedule';

  @override
  String get selectDaysAndTimeDescription =>
      'Select days of week and lesson times';

  @override
  String get daysOfWeek => 'Days of week';

  @override
  String get timeAndRooms => 'Time and rooms';

  @override
  String get validFromField => 'Valid from';

  @override
  String get teacherRequired => 'Teacher *';

  @override
  String get selectTeacherValidation => 'Select teacher';

  @override
  String get subjectOptional => 'Subject (optional)';

  @override
  String get notSpecifiedOption => 'Not specified';

  @override
  String get lessonTypeOptional => 'Lesson type (optional)';

  @override
  String get checkingConflictsStatus => 'Checking conflicts...';

  @override
  String conflictsCountChange(int count) {
    return 'Conflicts: $count (change time)';
  }

  @override
  String get hasConflicts => 'Has conflicts';

  @override
  String get selectRoomsValidation => 'Select rooms';

  @override
  String createSchedulesCountAction(int count) {
    return 'Create $count schedules';
  }

  @override
  String get createScheduleAction => 'Create schedule';

  @override
  String get selectAtLeastOneDayValidation => 'Select at least one day of week';

  @override
  String get selectRoomForEachDayValidation => 'Select room for each day';

  @override
  String schedulesCreatedCount(int count) {
    return 'Created $count schedule entries';
  }

  @override
  String get scheduleCreated => 'Schedule created';

  @override
  String get conflictTimeMessage => 'Conflict! Time is occupied';

  @override
  String get manageLessonsSection => 'Manage lessons';

  @override
  String futureLessonsFound(int count) {
    return 'Found $count future lessons';
  }

  @override
  String get noScheduledLessonsMessage => 'No scheduled lessons';

  @override
  String loadingErrorMessage(String error) {
    return 'Loading error: $error';
  }

  @override
  String get reassignTeacherTitle => 'Reassign teacher';

  @override
  String get reassignTeacherSubtitle => 'Select new teacher for all lessons';

  @override
  String get deleteAllFutureLessonsTitle => 'Delete all lessons';

  @override
  String get deleteAllFutureLessonsSubtitle =>
      'Subscription balance will not change';

  @override
  String get deleteAllLessonsQuestion => 'Delete all lessons?';

  @override
  String deleteAllLessonsMessage(int count, String name) {
    return 'Are you sure you want to delete $count future lessons for \"$name\"?\n\nSubscription balance will not change.';
  }

  @override
  String deletedLessonsCount(int count) {
    return 'Deleted $count lessons';
  }

  @override
  String get noAvailableTeachersMessage => 'No available teachers';

  @override
  String get selectTeacherTitle => 'Select teacher';

  @override
  String reassignedSlotsCount(int count) {
    return 'Reassigned $count slots';
  }

  @override
  String pausedSlotsCount(int count) {
    return 'Paused $count slots';
  }

  @override
  String get deactivateScheduleQuestion => 'Deactivate schedule?';

  @override
  String deactivateSlotsMessage(int count) {
    return 'Deactivate $count permanent schedule slots?\n\nSlots will remain in archive and can be restored.';
  }

  @override
  String get deactivateAction => 'Deactivate';

  @override
  String deactivatedSlotsCount(int count) {
    return 'Deactivated $count slots';
  }

  @override
  String scheduleSlotsDays(int count, String slots) {
    return '$count $slots';
  }

  @override
  String get slotWord => 'slot';

  @override
  String get slotsWordFew => 'slots';

  @override
  String get slotsWordMany => 'slots';

  @override
  String get pauseAllSlots => 'Pause';

  @override
  String get pauseAllSlotsSubtitle => 'Temporarily pause all slots';

  @override
  String get deactivateAllSlots => 'Deactivate';

  @override
  String get deactivateAllSlotsSubtitle => 'Disable permanent schedule';

  @override
  String get newTeacherLabel => 'New teacher';

  @override
  String allLessonsCanBeReassigned(int count) {
    return 'All $count lessons can be reassigned';
  }

  @override
  String canReassignCount(int count) {
    return 'Can reassign: $count lessons';
  }

  @override
  String reassignCount(int count) {
    return 'Reassign $count lessons';
  }

  @override
  String get reassignAllLessons => 'Reassign all lessons';

  @override
  String get noCompletedLessons => 'No completed lessons';

  @override
  String get noSubjectLabel => 'No subject';

  @override
  String get showMore => 'Show more';

  @override
  String get editStudentTitle => 'Edit';

  @override
  String get basicInfoSection => 'Basic information';

  @override
  String get fullNameField => 'Full name';

  @override
  String get phoneField => 'Phone';

  @override
  String get commentField => 'Comment';

  @override
  String get legacyBalanceSection => 'Lesson balance';

  @override
  String get currentBalance => 'Current balance';

  @override
  String balanceLessonsCount(int count) {
    return '$count lessons';
  }

  @override
  String get changeBalance => 'Change';

  @override
  String get changeBalanceTitle => 'Change balance';

  @override
  String get quantityField => 'Quantity';

  @override
  String get quantityHint => '+5 or -3';

  @override
  String get reasonOptional => 'Reason (optional)';

  @override
  String get applyAction => 'Apply';

  @override
  String get saveChangesAction => 'Save changes';

  @override
  String lessonsAddedCount(int count) {
    return 'Added $count lessons';
  }

  @override
  String lessonsDeductedCount(int count) {
    return 'Deducted $count lessons';
  }

  @override
  String get addLessonsTitle => 'Add lessons';

  @override
  String legacyBalanceLabel(int count) {
    return 'Lesson balance: $count';
  }

  @override
  String get lessonsQuantityField => 'Number of lessons';

  @override
  String get quantityPlaceholder => 'Positive or negative number';

  @override
  String get enterQuantity => 'Enter quantity';

  @override
  String get enterInteger => 'Enter integer';

  @override
  String get quantityCannotBeZero => 'Quantity cannot be 0';

  @override
  String get commentOptionalField => 'Comment (optional)';

  @override
  String get commentHint => 'E.g.: Transfer from another subscription';

  @override
  String get archiveStudentQuestion => 'Archive student?';

  @override
  String archiveStudentMessage(String name) {
    return 'Student \"$name\" will be moved to archive. You can restore them later.';
  }

  @override
  String get restoreStudentQuestion => 'Restore student?';

  @override
  String restoreStudentMessage(String name) {
    return 'Student \"$name\" will be restored from archive.';
  }

  @override
  String get deleteStudentQuestion => 'Delete student forever?';

  @override
  String deleteStudentMessage(String name) {
    return 'Student \"$name\" will be permanently deleted along with all data (lessons, payments, subscriptions).\n\nThis action CANNOT be undone!';
  }

  @override
  String get teacherDefault => 'Teacher';

  @override
  String get unknownName => 'Unknown';

  @override
  String get roomDefault => 'Room';

  @override
  String get checking => 'Checking...';

  @override
  String get freezeSubscription => 'Freeze subscription';

  @override
  String get freezeSubscriptionDescription =>
      'When frozen, the subscription validity period is paused. After unfreezing, the period will be extended by the number of frozen days.';

  @override
  String get daysCount => 'Number of days';

  @override
  String get enterQuantityValidation => 'Enter quantity';

  @override
  String get enterNumberFrom1To90 => 'Enter a number from 1 to 90';

  @override
  String get freeze => 'Freeze';

  @override
  String get subscriptionFrozen => 'Subscription frozen';

  @override
  String subscriptionUnfrozen(String date) {
    return 'Subscription unfrozen. Extended until $date';
  }

  @override
  String get extendSubscription => 'Extend term';

  @override
  String currentTermUntil(String date) {
    return 'Current term: until $date';
  }

  @override
  String get extendForDays => 'Extend for days';

  @override
  String get enterNumberFrom1To365 => 'Enter a number from 1 to 365';

  @override
  String get extend => 'Extend';

  @override
  String termExtendedUntil(String date) {
    return 'Term extended until $date';
  }

  @override
  String subscriptionBalanceLabel(int count) {
    return 'Subscriptions: $count';
  }

  @override
  String legacyBalanceShort(int count) {
    return 'Balance: $count';
  }

  @override
  String get addLessonsAction => 'Add lessons';

  @override
  String get avgCost => 'AVG COST';

  @override
  String get avgCostApprox => 'AVG COST ≈';

  @override
  String get noDataAvailable => 'no data';

  @override
  String get perLesson => 'per lesson';

  @override
  String get manageLessonsAction => 'Manage';

  @override
  String get conductedLabel => 'Conducted';

  @override
  String get cancelledLabel => 'Cancelled';

  @override
  String get discountLabel => 'Discount';

  @override
  String get correctionLabel => 'Corr.';

  @override
  String get legacyBalanceTitle => 'Lesson balance';

  @override
  String get exhaustedStatus => 'Exhausted';

  @override
  String get expiringSoon => 'Expiring soon';

  @override
  String get groupSubscription => 'Group';

  @override
  String frozenUntilDate(String date) {
    return 'Frozen until $date';
  }

  @override
  String expiredDate(String date) {
    return 'Expired $date';
  }

  @override
  String validUntilDate(String date) {
    return 'Valid until $date';
  }

  @override
  String get unfreezeAction => 'Unfreeze';

  @override
  String get teachersSection => 'Teachers';

  @override
  String get addTeacherTooltip => 'Add teacher';

  @override
  String get noLinkedTeachers => 'No linked teachers';

  @override
  String get addTeacherTitle => 'Add teacher';

  @override
  String get allTeachersAdded => 'All teachers already added';

  @override
  String get teacherAdded => 'Teacher added';

  @override
  String get removeTeacherQuestion => 'Remove teacher?';

  @override
  String get removeTeacherMessage =>
      'Teacher will be unlinked from this student.';

  @override
  String get teacherRemoved => 'Teacher removed';

  @override
  String get subjectsSection => 'Subjects';

  @override
  String get noLinkedSubjects => 'No linked subjects';

  @override
  String get addSubjectTitle => 'Add subject';

  @override
  String get allSubjectsAdded => 'All subjects already added';

  @override
  String get subjectAdded => 'Subject added';

  @override
  String get removeSubjectQuestion => 'Remove subject?';

  @override
  String get removeSubjectMessage =>
      'Subject will be unlinked from this student.';

  @override
  String get subjectRemoved => 'Subject removed';

  @override
  String get lessonTypesSection => 'Lesson types';

  @override
  String get noLinkedLessonTypes => 'No linked lesson types';

  @override
  String get addLessonTypeTitle => 'Add lesson type';

  @override
  String get allLessonTypesAdded => 'All lesson types already added';

  @override
  String get lessonTypeAdded => 'Lesson type added';

  @override
  String get removeLessonTypeQuestion => 'Remove lesson type?';

  @override
  String get removeLessonTypeMessage =>
      'Lesson type will be unlinked from this student.';

  @override
  String get lessonTypeRemoved => 'Lesson type removed';

  @override
  String get mergeWithAction => 'Merge with...';

  @override
  String selectStudentsToMerge(String name) {
    return 'Select students to merge with \"$name\"';
  }

  @override
  String get searchStudentsHint => 'Search students...';

  @override
  String get noStudentsToMerge => 'No students to merge';

  @override
  String balanceValue(int count) {
    return 'Balance: $count';
  }

  @override
  String get selectStudentsValidation => 'Select students';

  @override
  String nextWithCount(int count) {
    return 'Next ($count)';
  }

  @override
  String get groupCard => 'Group card';

  @override
  String get failedToLoadNames => 'Failed to load names';

  @override
  String archiveSlots(int count) {
    return 'Archive ($count)';
  }

  @override
  String get replacementRoom => 'Replacement';

  @override
  String pauseUntilDateFormat(String date) {
    return 'Paused until $date';
  }

  @override
  String get onPause => 'On pause';

  @override
  String get mondayShort2 => 'Mon';

  @override
  String get tuesdayShort2 => 'Tue';

  @override
  String get wednesdayShort2 => 'Wed';

  @override
  String get thursdayShort2 => 'Thu';

  @override
  String get fridayShort2 => 'Fri';

  @override
  String get saturdayShort2 => 'Sat';

  @override
  String get sundayShort2 => 'Sun';

  @override
  String get mondayFull => 'Monday';

  @override
  String get tuesdayFull => 'Tuesday';

  @override
  String get wednesdayFull => 'Wednesday';

  @override
  String get thursdayFull => 'Thursday';

  @override
  String get fridayFull => 'Friday';

  @override
  String get saturdayFull => 'Saturday';

  @override
  String get sundayFull => 'Sunday';

  @override
  String seriesStartDateLabel(String date) {
    return 'Start: $date';
  }

  @override
  String get editSeriesAction => 'Edit';

  @override
  String deleteSeriesLessons(int count) {
    return '$count lessons will be deleted from schedule. This action cannot be undone.';
  }

  @override
  String get saveSeries => 'Save';

  @override
  String get invalidTimeError => 'Invalid';

  @override
  String get roomFieldHint => 'Room';

  @override
  String get pauseScheduleUntilDate => 'Until what date to pause?';

  @override
  String get resumeDateLabel => 'Resume date';

  @override
  String get selectDateHint => 'Select date';

  @override
  String get pauseUntilMessage => 'Pause until';

  @override
  String get selectRoomLabel => 'New room';

  @override
  String get untilDateQuestion => 'Until date';

  @override
  String get applyRoomReplacement => 'Apply';

  @override
  String get archiveScheduleConfirm =>
      'Slot will be moved to archive. You can unarchive it later.';

  @override
  String get deleteScheduleConfirm =>
      'This slot will be deleted forever. This action cannot be undone.';

  @override
  String errorWithParam(String error) {
    return 'Error: $error';
  }

  @override
  String get createLessonsFromScheduleDescription =>
      'Lessons will be created based on the student\'s permanent schedule.';

  @override
  String get toDateLabel2 => 'To date';

  @override
  String get checkConflictsAction => 'Check conflicts';

  @override
  String get noConflictsFoundMessage => 'No conflicts found';

  @override
  String conflictsCountMessage(int count) {
    return 'Conflicts found: $count';
  }

  @override
  String get datesWillBeSkippedMessage => 'These dates will be skipped:';

  @override
  String andMoreLabel(int count) {
    return '...and $count more';
  }

  @override
  String get creatingMessage => 'Creating...';

  @override
  String lessonsCreatedResult(int count) {
    return 'Lessons created: $count';
  }

  @override
  String get addPermanentScheduleDescription =>
      'Select days of week and lesson times';

  @override
  String get timeAndRoomsLabel => 'Time and rooms';

  @override
  String get validFromLabel => 'Valid from';

  @override
  String get teacherRequiredLabel => 'Teacher *';

  @override
  String get selectTeacherError => 'Select teacher';

  @override
  String get subjectOptionalLabel => 'Subject (optional)';

  @override
  String get notSpecifiedLabel => 'Not specified';

  @override
  String get lessonTypeOptionalLabel => 'Lesson type (optional)';

  @override
  String conflictsChangeTime(int count) {
    return 'Conflicts: $count (change time)';
  }

  @override
  String get hasConflictsError => 'Has conflicts';

  @override
  String get selectRoomsError => 'Select rooms';

  @override
  String get checkingLabel => 'Checking...';

  @override
  String createCountSchedules(int count) {
    return 'Create $count schedules';
  }

  @override
  String get createScheduleLabel => 'Create schedule';

  @override
  String get selectAtLeastOneDay => 'Select at least one day of week';

  @override
  String get selectRoomForEachDay => 'Select room for each day';

  @override
  String get scheduleCreatedMessage => 'Schedule created';

  @override
  String schedulesCreatedMessage(int count) {
    return 'Created $count schedule entries';
  }

  @override
  String get conflictTimeOccupiedMessage => 'Conflict! Time is occupied';

  @override
  String deleteAllLessonsConfirm(int count, String name) {
    return 'Are you sure you want to delete $count future lessons for \"$name\"?\n\nSubscription balance will not change.';
  }

  @override
  String deletedCountLessons(int count) {
    return 'Deleted $count lessons';
  }

  @override
  String get noAvailableTeachersError => 'No available teachers';

  @override
  String get selectTeacherLabel => 'Select teacher';

  @override
  String get noNameLabel => 'No name';

  @override
  String reassignedSlotsMessage(int count) {
    return 'Reassigned $count slots';
  }

  @override
  String pausedSlotsMessage(int count) {
    return 'Paused $count slots';
  }

  @override
  String deactivateScheduleConfirm(int count) {
    return 'Deactivate $count permanent schedule slots?\n\nSlots will remain in archive and can be restored.';
  }

  @override
  String deactivatedSlotsMessage(int count) {
    return 'Deactivated $count slots';
  }

  @override
  String get manageLessonsHeader => 'Manage lessons';

  @override
  String loadingErrorLabel(String error) {
    return 'Loading error: $error';
  }

  @override
  String get noScheduledLessonsLabel => 'No scheduled lessons';

  @override
  String foundFutureLessons(int count) {
    return 'Found $count future lessons';
  }

  @override
  String get reassignTeacherSubtitleLabel =>
      'Select new teacher for all lessons';

  @override
  String get deleteAllLessonsLabel => 'Delete all lessons';

  @override
  String get subscriptionBalanceWontChange =>
      'Subscription balance will not change';

  @override
  String get permanentScheduleLabel => 'Permanent schedule';

  @override
  String slotsCountLabel(int count, String slots) {
    return '$count $slots';
  }

  @override
  String get forAllScheduleSlots => 'For all schedule slots';

  @override
  String get temporaryPauseAllSlots => 'Temporarily pause all slots';

  @override
  String get disablePermanentSchedule => 'Disable permanent schedule';

  @override
  String get noLessonsToReassignError => 'No lessons to reassign';

  @override
  String reassignedLessonsMessage(int count) {
    return 'Reassigned $count lessons';
  }

  @override
  String get reassignTeacherHeader => 'Reassign teacher';

  @override
  String get newTeacherFieldLabel => 'New teacher';

  @override
  String allLessonsCanReassign(int count) {
    return 'All $count lessons can be reassigned';
  }

  @override
  String foundConflictsCount(int count) {
    return 'Found conflicts: $count';
  }

  @override
  String canReassignLessons(int count) {
    return 'Can reassign: $count lessons';
  }

  @override
  String reassignLessonsCount(int count) {
    return 'Reassign $count lessons';
  }

  @override
  String get reassignAllLessonsLabel => 'Reassign all lessons';

  @override
  String get lessonHistoryHeader => 'Lesson history';

  @override
  String get noCompletedLessonsLabel => 'No completed lessons';

  @override
  String get showMoreAction => 'Show more';

  @override
  String get noSubjectPlaceholder => 'No subject';

  @override
  String get studentUpdatedMessage => 'Student updated';

  @override
  String get enterLessonsCountValidation => 'Enter number of lessons';

  @override
  String lessonsAddedMessage(int count) {
    return 'Added $count lessons';
  }

  @override
  String lessonsDeductedMessage(int count) {
    return 'Deducted $count lessons';
  }

  @override
  String get editStudentHeader => 'Edit';

  @override
  String get basicInfoHeader => 'Basic information';

  @override
  String get fullNameFieldLabel => 'Full name';

  @override
  String get enterNameError => 'Enter name';

  @override
  String get phoneFieldLabel => 'Phone';

  @override
  String get commentFieldLabel => 'Comment';

  @override
  String get legacyBalanceHeader => 'Lesson balance';

  @override
  String get currentBalanceLabel => 'Current balance';

  @override
  String get changeBalanceAction => 'Change';

  @override
  String get changeBalanceHeader => 'Change balance';

  @override
  String get quantityFieldLabel => 'Quantity';

  @override
  String get reasonOptionalLabel => 'Reason (optional)';

  @override
  String get applyChangeAction => 'Apply';

  @override
  String get quantityCannotBeZeroError => 'Number of lessons cannot be 0';

  @override
  String get addLessonsHeader => 'Add lessons';

  @override
  String legacyBalanceDisplay(int count) {
    return 'Lesson balance: $count';
  }

  @override
  String get lessonsQuantityFieldLabel => 'Number of lessons';

  @override
  String get positiveOrNegativeHint => 'Positive or negative number';

  @override
  String get enterQuantityError => 'Enter quantity';

  @override
  String get enterIntegerError => 'Enter integer';

  @override
  String get commentOptionalLabel => 'Comment (optional)';

  @override
  String get transferFromSubscriptionHint =>
      'E.g.: Transfer from another subscription';

  @override
  String get saveAction => 'Save';

  @override
  String lessonWillNotShowOnDate(String date) {
    return 'Lesson will not be displayed on $date.\n\nThis will not create an entry in lesson history.';
  }

  @override
  String get lessonDeletedWithPayment =>
      'Lesson will be deleted from history.\nPayment for the lesson will also be deleted.';

  @override
  String get lessonDeletedWithReturn =>
      'Lesson will be deleted from history.\nDeducted lesson will be returned to student balance.';

  @override
  String get lessonDeletedCompletely =>
      'Lesson will be completely deleted from history.';

  @override
  String get lessonPaymentDefault => 'Lesson payment';

  @override
  String get lessonWillBeCancelledNoDeduction =>
      'Lesson will be cancelled and archived without balance deduction';

  @override
  String get deductedLessonWillBeReturned =>
      'Deducted lesson will be automatically returned to balance.';

  @override
  String get whoToDeductLesson => 'Who to deduct lesson from:';

  @override
  String lessonIsPartOfSeries(int count) {
    return 'This lesson is part of a series ($count lessons)';
  }

  @override
  String get deductionAppliesToTodayOnly =>
      'Deduction applies only to today\'s lesson';

  @override
  String get allSeriesLessonsWillBeArchived =>
      'All series lessons will be archived without deduction';

  @override
  String get cancelLessonAction => 'Cancel lesson';

  @override
  String get lessonSeriesCancelled => 'Lesson series cancelled';

  @override
  String get lessonCancelledAndDeducted =>
      'Lesson cancelled and deducted from balance';

  @override
  String get lessonIsPartOfPermanentSchedule =>
      'This lesson is part of permanent schedule';

  @override
  String get participantsLabel => 'Participants';

  @override
  String get paymentLabel => 'Payment';

  @override
  String paymentErrorMessage(String error) {
    return 'Payment error: $error';
  }

  @override
  String removeStudentFromLessonConfirm(String name) {
    return 'Remove $name from this lesson?';
  }

  @override
  String get removeParticipantFromLesson =>
      'Remove participant from this lesson?';

  @override
  String get allStudentsAlreadyAdded => 'All students already added';

  @override
  String get roomLabel2 => 'Room';

  @override
  String roomWithNumberLabel(String number) {
    return 'Room $number';
  }

  @override
  String get studentFieldLabel => 'Student';

  @override
  String get notSelectedOption => 'Not selected';

  @override
  String get repeatNone => 'No repeat';

  @override
  String get repeatDaily => 'Every day';

  @override
  String get repeatWeeklyOption => 'Every week';

  @override
  String get repeatWeekdays => 'By weekdays';

  @override
  String get repeatCustom => 'Custom dates';

  @override
  String get editScopeThisOnly => 'Only this lesson';

  @override
  String get editScopeThisAndFollowing => 'This and following';

  @override
  String get editScopeAll => 'All lessons in series';

  @override
  String get editScopeSelected => 'Selected';

  @override
  String roomAddedMessage(String name) {
    return 'Room \"$name\" added';
  }

  @override
  String get roomNameOptionalLabel => 'Name (optional)';

  @override
  String get roomNameHintExample => 'E.g.: Piano room';

  @override
  String get createRoomAction => 'Create room';

  @override
  String get noOwnStudentsMessage => 'You have no own students';

  @override
  String showAllStudents(int count) {
    return 'Show all ($count)';
  }

  @override
  String get otherStudentsSection => 'Other students';

  @override
  String get hideAction => 'Hide';

  @override
  String get quickAddMessage => 'Quick add';

  @override
  String get createStudentAction => 'Create student';

  @override
  String get addSubjectForLessons => 'Add a subject for lessons';

  @override
  String get createSubjectAction => 'Create subject';

  @override
  String get configureLessonParams => 'Configure lesson parameters';

  @override
  String get enterNameRequired => 'Enter name';

  @override
  String get minutesUnit => 'min';

  @override
  String get createTypeAction => 'Create type';

  @override
  String get teachersFilter => 'Teachers';

  @override
  String get lessonTypesFilter => 'Lesson types';

  @override
  String get directionsFilter => 'Subjects';

  @override
  String get applyFiltersAction => 'Apply filters';

  @override
  String get showAllAction => 'Show all';

  @override
  String get studentsFilter => 'Students';

  @override
  String get deletedLabel => 'Deleted';

  @override
  String get temporarilyShowingAll => 'Temporarily showing all';

  @override
  String get allRoomsLabel => 'All rooms';

  @override
  String get noDataLabel => 'No data';

  @override
  String get selectDatesTitle => 'Select dates';

  @override
  String get lessonSegment => 'Lesson';

  @override
  String get bookingSegment => 'Booking';

  @override
  String get roomRequired => 'Room *';

  @override
  String get noRoomsMessage => 'No rooms';

  @override
  String get addRoomTooltip => 'Add room';

  @override
  String get roomsLabel => 'Rooms';

  @override
  String roomAbbr(String number) {
    return 'Room $number';
  }

  @override
  String get studentSegment => 'Student';

  @override
  String get groupSegment => 'Group';

  @override
  String get selectStudentHint => 'Select student';

  @override
  String get noGroupsMessage => 'No groups';

  @override
  String get addSubjectTooltip2 => 'Add subject';

  @override
  String get addLessonTypeTooltip2 => 'Add lesson type';

  @override
  String get lessonsCountQuestion => 'Number of lessons:';

  @override
  String get mondayAbbr => 'Mon';

  @override
  String get tuesdayAbbr => 'Tue';

  @override
  String get wednesdayAbbr => 'Wed';

  @override
  String get thursdayAbbr => 'Thu';

  @override
  String get fridayAbbr => 'Fri';

  @override
  String get saturdayAbbr => 'Sat';

  @override
  String get sundayAbbr => 'Sun';

  @override
  String get checkingConflictsLabel => 'Checking conflicts...';

  @override
  String willCreateLessonsCount(int count) {
    return 'Will create $count lessons';
  }

  @override
  String get createLessonLabel => 'Create lesson';

  @override
  String get roomsBookedMessage => 'Rooms booked';

  @override
  String get invalidLabel => 'Invalid';

  @override
  String get minLessonDurationMessage =>
      'Minimum lesson duration is 15 minutes';

  @override
  String lessonsCreatedSkippedCount(int created, int skipped) {
    return 'Created $created lessons (skipped: $skipped)';
  }

  @override
  String get bookedLabel => 'Booked';

  @override
  String get deleteBookingAction => 'Delete booking';

  @override
  String get selectMinOneRoom => 'Select at least one room';

  @override
  String get descriptionHintExample => 'E.g.: Rehearsal, Event';

  @override
  String temporaryRoomUntilMessage(String room, String date) {
    return 'Temporarily in room $room until $date';
  }

  @override
  String slotWillNotWorkOnDateFull(String date) {
    return 'Slot will not work on $date.\n\nThis will allow creating another lesson at this time.';
  }

  @override
  String get exceptionAddedMessage => 'Exception added';

  @override
  String get slotResumedMessage => 'Slot resumed';

  @override
  String get slotDeactivateConfirm =>
      'Slot will be completely disabled and will not appear in schedule.\n\nYou can reactivate it in the student card.';

  @override
  String get slotDeactivatedMessage => 'Slot deactivated';

  @override
  String studentNameLabel(String name) {
    return 'Student: $name';
  }

  @override
  String willBeCreatedCount(int count) {
    return 'Will create: $count lessons';
  }

  @override
  String createdLessonsCount(int count) {
    return 'Created $count lessons';
  }

  @override
  String get applyChangesAction => 'Apply changes';

  @override
  String get changeScopeLabel => 'Change scope';

  @override
  String seriesLessonsTitle(int count) {
    return 'Series lessons ($count)';
  }

  @override
  String selectedLabel(int count) {
    return 'Selected: $count';
  }

  @override
  String get changesLabel => 'Changes';

  @override
  String updatedLessonsSkipped(int updated, int skipped) {
    return 'Updated $updated lessons (skipped: $skipped)';
  }

  @override
  String updatedLessonsCount(int count) {
    return 'Updated $count lessons';
  }

  @override
  String get allRoomsDisplayed => 'Showing all rooms';

  @override
  String selectedRoomsCount(int count) {
    return 'Selected rooms: $count';
  }

  @override
  String get defaultRoomsLabel => 'Default rooms';

  @override
  String get roomSetupFirstTimeHint =>
      'Only selected rooms will be displayed in the schedule. You can change this setting anytime in the filter menu.';

  @override
  String get roomSetupHint =>
      'Select rooms to display in the schedule by default.';

  @override
  String get selectRoomsAction => 'Select rooms';

  @override
  String saveCountAction(int count) {
    return 'Save ($count)';
  }

  @override
  String get virtualLessonLabel => 'Virtual lesson';

  @override
  String lessonWillNotShowMessage(String date) {
    return 'Lesson will not appear on $date.\n\nThis will not create a lesson history entry.';
  }

  @override
  String get schedulePausedMessage => 'Schedule paused';

  @override
  String get scheduleResumedSuccessMessage => 'Schedule resumed';

  @override
  String get scheduleDeactivatedMessage => 'Schedule deactivated';

  @override
  String conflictsLabel(int count) {
    return 'Conflicts: $count';
  }

  @override
  String willBeChangedCount(int count) {
    return 'Will change: $count lessons';
  }

  @override
  String conflictsWillBeSkippedLabel(int count) {
    return 'Conflicts: $count (will be skipped)';
  }

  @override
  String errorFormat(String error) {
    return 'Error: $error';
  }

  @override
  String get theseDatesWillBeSkipped => 'These dates will be skipped:';

  @override
  String andMore(int count) {
    return '...and $count more';
  }

  @override
  String get enabledForAdmin => 'Enabled for admin';

  @override
  String get teacherSubjectsLabel => 'SUBJECTS';

  @override
  String get teacherSubjectsHint => 'Subjects taught by teacher';

  @override
  String get noDirectionsHint =>
      'No subjects specified.\nAdd subjects taught by the teacher.';

  @override
  String get unknownSubject => 'Unknown';

  @override
  String get addDirectionTitle => 'Add subject';

  @override
  String selectSubjectFor(String name) {
    return 'Select subject for $name';
  }

  @override
  String directionAdded(String name) {
    return 'Subject \"$name\" added';
  }

  @override
  String get addSubjectDescription => 'Add a subject for lessons';

  @override
  String get subjectNameField => 'Subject name';

  @override
  String get nameField => 'Name';

  @override
  String get minSuffix => 'min';

  @override
  String get priceOptional => 'Price (optional)';

  @override
  String get showAll => 'Show all';

  @override
  String get deleted => 'Deleted';

  @override
  String studentAddedAsGuest(String name) {
    return '$name added as guest';
  }

  @override
  String roomWithNumberDefault(String number) {
    return 'Room $number';
  }

  @override
  String showAllStudentsCount(int count) {
    return 'Show all ($count)';
  }

  @override
  String get otherStudentsLabel => 'Other students';

  @override
  String studentNameAddedMessage(String name) {
    return 'Student \"$name\" added';
  }

  @override
  String subjectNameAddedMessage(String name) {
    return 'Subject \"$name\" added';
  }

  @override
  String lessonTypeNameAddedMessage(String name) {
    return 'Lesson type \"$name\" added';
  }

  @override
  String durationMinutesLabel(int minutes) {
    return '$minutes min';
  }

  @override
  String lessonTypeDurationFormat(String name, int duration) {
    return '$name ($duration min)';
  }

  @override
  String groupMembersCount(String name, int count) {
    return '$name ($count st.)';
  }

  @override
  String get roomSetupFirstTimeDescription =>
      'Only selected rooms will be displayed in the schedule. You can change this setting at any time through the filters menu.';

  @override
  String get roomSetupDescription =>
      'Select rooms that will be displayed in the schedule by default.';

  @override
  String saveWithCountLabel(int count) {
    return 'Save ($count)';
  }

  @override
  String get allRoomsDisplayedMessage => 'All rooms displayed';

  @override
  String selectedRoomsCountMessage(int count) {
    return 'Selected rooms: $count';
  }

  @override
  String get temporarilyShowingAllRooms => 'Temporarily showing all';

  @override
  String get notConfiguredRooms => 'Not configured';

  @override
  String get allRoomsDefault => 'All rooms';

  @override
  String get noDataAvailableMessage => 'No data';

  @override
  String get januaryMonth => 'January';

  @override
  String get februaryMonth => 'February';

  @override
  String get marchMonth => 'March';

  @override
  String get aprilMonth => 'April';

  @override
  String get mayMonth => 'May';

  @override
  String get juneMonth => 'June';

  @override
  String get julyMonth => 'July';

  @override
  String get augustMonth => 'August';

  @override
  String get septemberMonth => 'September';

  @override
  String get octoberMonth => 'October';

  @override
  String get novemberMonth => 'November';

  @override
  String get decemberMonth => 'December';

  @override
  String get selectDatesLabel => 'Select dates';

  @override
  String get lessonTabLabel => 'Lesson';

  @override
  String get bookingTabLabel => 'Booking';

  @override
  String get noRoomsAvailableMessage => 'No rooms';

  @override
  String roomAbbreviation(String number) {
    return 'Rm. $number';
  }

  @override
  String get descriptionOptionalField => 'Description (optional)';

  @override
  String get eventMeetingHint => 'Event, meeting, etc.';

  @override
  String get studentTabLabel => 'Student';

  @override
  String get groupTabLabel => 'Group';

  @override
  String get noStudentsAvailableMessage => 'No students';

  @override
  String get selectStudentLabel => 'Select student';

  @override
  String get noGroupsAvailableMessage => 'No groups';

  @override
  String get lessonTimeTitle => 'Lesson time';

  @override
  String get selectDatesInCalendarLabel => 'Select dates in calendar';

  @override
  String selectedDatesCountLabel(int count) {
    return 'Selected: $count dates';
  }

  @override
  String get checkingConflictsProgress => 'Checking conflicts...';

  @override
  String willCreateLessonsCountMessage(int count) {
    return 'Will create $count lessons';
  }

  @override
  String conflictsWillBeSkippedMessage(int count) {
    return 'Conflicts: $count (will be skipped)';
  }

  @override
  String createSchedulesCountLabel(int count) {
    return 'Create $count schedules';
  }

  @override
  String get createScheduleActionLabel => 'Create schedule';

  @override
  String createLessonsCountLabel(int count) {
    return 'Create $count lessons';
  }

  @override
  String get createLessonActionLabel => 'Create lesson';

  @override
  String get minBookingDurationError =>
      'Minimum booking duration is 15 minutes';

  @override
  String get roomsBookedSuccess => 'Rooms booked';

  @override
  String durationHoursMinutesFormat(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationHoursOnlyFormat(int hours) {
    return '${hours}h';
  }

  @override
  String durationMinutesOnlyFormat(int minutes) {
    return '${minutes}m';
  }

  @override
  String get invalidTimeLabel => 'Invalid';

  @override
  String dayStartTimeHelpText(String day) {
    return '$day: Start time';
  }

  @override
  String dayEndTimeHelpText(String day) {
    return '$day: End time';
  }

  @override
  String get minLessonDurationError => 'Minimum lesson duration is 15 minutes';

  @override
  String permanentSchedulesCreatedMessage(int count) {
    return 'Created $count permanent schedules';
  }

  @override
  String get permanentScheduleCreatedMessage => 'Permanent schedule created';

  @override
  String get allDatesOccupiedError => 'All dates occupied';

  @override
  String lessonsCreatedSkippedMessage(int created, int skipped) {
    return 'Created $created lessons (skipped: $skipped)';
  }

  @override
  String lessonsCreatedSuccessMessage(int count) {
    return 'Created $count lessons';
  }

  @override
  String get groupLessonCreatedMessage => 'Group lesson created';

  @override
  String get lessonCreatedSuccessMessage => 'Lesson created';

  @override
  String get enterGroupName => 'Enter name';

  @override
  String get unknownUserLabel => 'Unknown user';

  @override
  String get deletingProgress => 'Deleting...';

  @override
  String get deleteBookingActionLabel => 'Delete booking';

  @override
  String get bookingWillBeDeletedMessage =>
      'Booking will be deleted and rooms will be freed.';

  @override
  String get bookingDeletedSuccess => 'Booking deleted';

  @override
  String get deletionErrorMessage => 'Deletion error';

  @override
  String get bookRoomsLabel => 'Book rooms';

  @override
  String get selectMinOneRoomMessage => 'Select at least one room';

  @override
  String get bookingErrorMessage => 'Booking error';

  @override
  String slotExceptionMessage(String date) {
    return 'Slot will not work on $date.\n\nThis will allow creating another lesson at this time.';
  }

  @override
  String get exceptionAddedSuccess => 'Exception added';

  @override
  String get pauseUntilHelpText => 'Pause until';

  @override
  String slotPausedUntilMessage(String date) {
    return 'Slot paused until $date';
  }

  @override
  String get slotResumedSuccess => 'Slot resumed';

  @override
  String get slotDeactivateMessage =>
      'Slot will be completely disabled and won\'t be displayed in the schedule.\n\nYou can activate it again in the student card.';

  @override
  String get slotDeactivatedSuccess => 'Slot deactivated';

  @override
  String studentLabelWithName(String name) {
    return 'Student: $name';
  }

  @override
  String get toDateLabelSchedule => 'To date';

  @override
  String willBeCreatedCountMessage(int count) {
    return 'Will be created: $count lessons';
  }

  @override
  String get creatingProgress => 'Creating...';

  @override
  String get createLessonsActionLabel => 'Create lessons';

  @override
  String get noDatesToCreateError => 'No dates to create';

  @override
  String get roomNotSpecifiedError => 'Room not specified';

  @override
  String get editSeriesLabel => 'Edit series';

  @override
  String get savingProgress => 'Saving...';

  @override
  String get byWeekdaysFilterLabel => 'By weekdays';

  @override
  String get allLessonsLabel => 'All';

  @override
  String seriesLessonsLabel(int count) {
    return 'Series lessons ($count)';
  }

  @override
  String selectedCountLabel(int count) {
    return 'Selected: $count';
  }

  @override
  String get timeChangeLabel => 'Time';

  @override
  String get roomChangeLabel => 'Room';

  @override
  String get studentChangeLabel => 'Student';

  @override
  String get subjectChangeLabel => 'Subject';

  @override
  String get lessonTypeChangeLabel => 'Lesson type';

  @override
  String get currentValueLabel => 'current';

  @override
  String willBeChangedCountMessage(int count) {
    return 'Will be changed: $count lessons';
  }

  @override
  String get noLessonsToUpdateError =>
      'No lessons to update (all have conflicts)';

  @override
  String updatedLessonsSkippedMessage(int updated, int skipped) {
    return 'Updated $updated lessons (skipped: $skipped)';
  }

  @override
  String updatedLessonsSuccessMessage(int count) {
    return 'Updated $count lessons';
  }

  @override
  String lessonSchedulePaused(String date) {
    return 'Paused until $date';
  }

  @override
  String get lessonScheduleIndefinitePause => 'Indefinite pause';

  @override
  String temporaryRoomReplacementInfo(String room, String date) {
    return 'Temporarily in room $room until $date';
  }

  @override
  String createLessonOnDateLabel(String date) {
    return 'Create lesson on $date';
  }

  @override
  String completeLessonOnDateLabel(String date) {
    return 'Complete lesson on $date';
  }

  @override
  String cancelLessonOnDateLabel(String date) {
    return 'Cancel lesson on $date';
  }

  @override
  String get lessonCompletedSuccess => 'Lesson completed';

  @override
  String get dateSkippedSuccess => 'Date skipped';

  @override
  String get schedulePausedSuccess => 'Schedule paused';

  @override
  String get scheduleResumedSuccess => 'Schedule resumed';

  @override
  String get scheduleDeactivatedSuccess => 'Schedule deactivated';

  @override
  String get january => 'Январь';

  @override
  String get february => 'Февраль';

  @override
  String get march => 'Март';

  @override
  String get april => 'Апрель';

  @override
  String get may => 'Май';

  @override
  String get june => 'Июнь';

  @override
  String get july => 'Июль';

  @override
  String get august => 'Август';

  @override
  String get september => 'Сентябрь';

  @override
  String get october => 'Октябрь';

  @override
  String get november => 'Ноябрь';

  @override
  String get december => 'Декабрь';

  @override
  String get changes => 'Изменения';

  @override
  String get editSeries => 'Редактировать серию';

  @override
  String get saving => 'Сохранение...';

  @override
  String get applyChanges => 'Применить изменения';

  @override
  String get byDaysOfWeek => 'По дням недели';

  @override
  String get current => 'текущий';

  @override
  String seriesLessonsCount(int count) {
    return 'Занятия серии ($count)';
  }

  @override
  String willBeChangedLessons(int count) {
    return 'Будет изменено: $count занятий';
  }

  @override
  String get creating => 'Создание...';

  @override
  String get createLessonsButton => 'Создать занятия';

  @override
  String willBeCreatedLessons(int count) {
    return 'Будет создано: $count занятий';
  }

  @override
  String get fromDate => 'С даты';

  @override
  String get toDate => 'По дату';

  @override
  String get bookRooms => 'Забронировать кабинеты';

  @override
  String get selectRooms => 'Выберите кабинеты';

  @override
  String get selectAtLeastOneRoomValidation => 'Выберите минимум один кабинет';

  @override
  String createLessonOn(String date) {
    return 'Создать занятие на $date';
  }

  @override
  String exceptionMessage(String date) {
    return 'Слот не будет действовать $date.\n\nЭто позволит создать другое занятие в это время.';
  }

  @override
  String temporaryRoomMessage(String room, String date) {
    return 'Временно в кабинете $room до $date';
  }

  @override
  String get deleting => 'Удаление...';

  @override
  String get deleteError => 'Ошибка при удалении';

  @override
  String get roomSetupDefaultDescription =>
      'Выберите кабинеты, которые будут отображаться в расписании по умолчанию.';

  @override
  String get selectRoomsPlaceholder => 'Выберите кабинеты';

  @override
  String completeLessonOn(String date) {
    return 'Провести занятие на $date';
  }

  @override
  String cancelLessonOn(String date) {
    return 'Отменить занятие на $date';
  }

  @override
  String paymentLessonsWithDate(int count, String date) {
    return '$count lessons • $date';
  }

  @override
  String subscriptionLessonsProgress(int remaining, int total) {
    return '$remaining / $total lessons';
  }

  @override
  String daysRemainingShort(int days) {
    return '($days d.)';
  }
}
