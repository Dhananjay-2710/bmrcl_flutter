import 'package:bmrcl/features/shifts/providers/week_off_provider.dart';
import 'package:bmrcl/features/shifts/services/week_off_service.dart';
import 'package:bmrcl/providers/imagepicker_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'constants/api_constants.dart';
import 'core/api_client.dart';

// services
import 'features/auth/services/auth_service.dart';
import 'features/shifts/services/shift_service.dart';
import 'features/shifts/services/attendance_service.dart';
import 'features/shifts/services/shift_assign_service.dart';
import 'features/shifts/services/lookup_service.dart';
import 'features/notifications/services/notifications_service.dart';
import 'features/leave/services/leave_service.dart';

// providers1 (state)
import 'features/auth/providers/auth_provider.dart';
import 'features/shifts/providers/shifts_provider.dart';
import 'features/shifts/providers/shift_assign_provider.dart';
import 'features/shifts/providers/lookup_provider.dart';
import 'features/dashboard/providers/admin_provider.dart';
import 'features/dashboard/services/admin_service.dart';
import 'features/devices/providers/devices_provider.dart';
import 'features/devices/services/device_service.dart';
import 'features/faqs/providers/faqs_provider.dart';
import 'features/faqs/services/faq_service.dart';
import 'features/notes/providers/notes_provider.dart';
import 'features/notes/services/notes_service.dart';
import 'features/tasks/providers/tasks_provider.dart';
import 'features/tasktype/providers/task_type_provider.dart';
import 'features/users/providers/users_provider.dart';
import 'features/users/services/user_service.dart';
import 'features/notifications/providers/notifications_provider.dart';
import 'features/leave/providers/leave_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create providers
  final providers = [
    // 1) core
    Provider<ApiClient>(create: (_) => ApiClient(baseUrl: ApiConstants.baseUrl)),

    // 2) services (ABOVE the providers that read them)
    Provider<AuthService>(create: (ctx) => AuthService(ctx.read<ApiClient>())),
    Provider<ShiftService>(create: (ctx) => ShiftService(ctx.read<ApiClient>())),
    Provider<AttendanceService>(create: (ctx) => AttendanceService(ctx.read<ApiClient>())),
    Provider<ShiftAssignService>(create: (ctx) => ShiftAssignService(ctx.read<ApiClient>())),
    Provider<LookupService>(create: (ctx) => LookupService(ctx.read<ApiClient>())),
    Provider<NotificationsService>(create: (ctx) => NotificationsService(ctx.read<ApiClient>())),
    Provider<WeekOffService>(create: (ctx) => WeekOffService(ctx.read<ApiClient>())),
    Provider<LeaveService>(create: (ctx) => LeaveService(ctx.read<ApiClient>())),
    Provider<UserService>(create: (ctx) => UserService(ctx.read<ApiClient>())),
    Provider<DeviceService>(create: (ctx) => DeviceService(ctx.read<ApiClient>())),
    Provider<FaqService>(create: (ctx) => FaqService(ctx.read<ApiClient>())),
    Provider<NotesService>(create: (ctx) => NotesService(ctx.read<ApiClient>())),
    Provider<AdminService>(create: (ctx) => AdminService(ctx.read<ApiClient>())),

    // 3) state providers
    ChangeNotifierProvider<AuthProvider>(create: (ctx) => AuthProvider(ctx.read<AuthService>())),
    ChangeNotifierProvider<ShiftsProvider>(
      create: (ctx) => ShiftsProvider(
        ctx.read<ShiftService>(),
        ctx.read<AttendanceService>(),
      ),
    ),
    ChangeNotifierProvider<ShiftAssignProvider>(
      create: (ctx) => ShiftAssignProvider(ctx.read<ShiftAssignService>()),
    ),
    ChangeNotifierProvider<LookupProvider>(
      create: (ctx) => LookupProvider(ctx.read<LookupService>()),
    ),

    // ✅ NotificationsProvider WITHOUT token here
    ChangeNotifierProvider<NotificationsProvider>(
      create: (ctx) => NotificationsProvider(service: ctx.read<NotificationsService>()),
    ),
    ChangeNotifierProvider<WeekOffProvider>(
      create: (ctx) => WeekOffProvider(ctx.read<WeekOffService>()),
    ),
    ChangeNotifierProvider<LeaveProvider>(
      create: (ctx) => LeaveProvider(ctx.read<LeaveService>()),
    ),

    ChangeNotifierProvider(create: (_) => ImagePickerProvider()),
    // others
    ChangeNotifierProvider(create: (ctx) => UsersProvider(ctx.read<UserService>())),
    ChangeNotifierProvider(create: (ctx) => DevicesProvider(ctx.read<DeviceService>())),
    ChangeNotifierProvider(create: (_) => TasksProvider()),
    ChangeNotifierProvider(create: (ctx) => FaqsProvider(ctx.read<FaqService>())),
    ChangeNotifierProvider(create: (ctx) => AdminProvider(ctx.read<AdminService>())),
    ChangeNotifierProvider(create: (ctx) => NotesProvider(ctx.read<NotesService>())),
    ChangeNotifierProvider(create: (_) => TaskTypeProvider()),
  ];

  runApp(
    MultiProvider(
      providers: providers,
      child: const MyApp(),
    ),
  );
}
