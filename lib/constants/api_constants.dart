class ApiConstants {
  // Basic URL
  static const String baseUrl = 'https://demo.ctrmv.com/veriphy/public/api/v1';
  static const String refreshEndpoint = '/refresh';
  // Login / Logout URL
  static const String loginEndpoint = '/login';
  static const String profileEndpoint = '/profile';
  static const String logoutEndpoint = '/logout';
  static const String resetPasswordEndpoint = '/reset_password';
  static const String verifyEmailCodeEndpoint = "/verify-email-code";
  static const String resendEmailCodeEndpoint = "/resend-email-code";

  // Dashboard URL
  static const String adminDashboard = "/admin_dashboard";

  // Tasks URL
  static const String faqEndpoint = '/faqs/list';
  static const String allTasks = '/tasks/list';
  static const String myTasks = '/tasks/tasklist';
  static const String storeTask = '/tasks/store';

  // Task Type
  static const String allTaskType = '/task_type/list';

  // Users URL
  static const String userListEndpoint = '/user/list';
  static String userUpdateEndpoint(int id) => '/user/update/$id';

  // Devices URL
  static const String deviceListEndpoint = '/devices/list';

  // Notes URL
  static const String noteListEndpoint = '/notes/list';
  static const String noteStoreEndpoint = '/notes/store';
  static const String noteUpdateEndpoint = '/notes/update';
  static const String noteDeleteEndpoint = '/notes/delete';

  // Assign Shifts URL
  static const String myShiftEndpoint = '/assign_shift/attendance/list';
  static const String checkInEndpoint = '/assign_shift/attendance/checkin';
  static const String checkOutEndpoint = '/assign_shift/attendance/checkout';
  static const String shiftsList = 'shifts/list';

  // Station URL
  static const String stationsList = 'stations/list';
  static const String stationListEndpoint = '/stations/list';

  // Gate URL
  static String stationsGates(int id) => 'stations/getgate/$id';

  // Shift URL
  static const String shiftAssignList = 'shift_assign/list';
  static const String shiftAssignStore = 'shift_assign/store';
  static const String shiftAssignBulkStore = 'shift_assign/store_bulk';
  static String shiftAssignUpdate(int id) => 'shift_assign/update/$id';
  static String shiftAssignDelete(int id) => 'shift_assign/delete/$id';
  static String shiftAssignShow(int id) => 'shift_assign/show/$id';

  // Notifications
  static const notificationsList = '/notifications/list';
  static const notificationsUnread = '/notifications/unread';
  static const notificationsRead = '/notifications/read';
  static const notificationsReadAll = '/notifications/read-all';

  // Week Off
  static const String weekOffListEndpoint = '/week_off/list';
  static const String weekOffCreateEndpoint = '/week_off/store';
  static const String weekOffEndpoint = '/week_off';

  // Leave
  static const String leaveListEndpoint = '/leaves/list';
  static const String myLeaveEndpoint = '/leaves/listleaveata';
  static const String leaveStoreEndpoint = '/leaves/store';
  static String leaveReviewEndpoint(int id) => '/leaves/review_leave/$id';
  static String leaveApproveEndpoint(int id) => '/leaves/approved_leave/$id';
  static String leaveUpdateEndpoint(int id) => '/leaves/update/$id';
  static String leaveDeleteEndpoint(int id) => '/leaves/delete/$id';
}
