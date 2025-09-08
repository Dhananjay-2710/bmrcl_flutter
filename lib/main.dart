import 'package:bmrcl/features/shifts/providers/week_off_provider.dart';
import 'package:bmrcl/features/shifts/services/week_off_service.dart';
import 'package:bmrcl/providers/imagepicker_provider.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

// providers1 (state)
import 'features/auth/providers/auth_provider.dart';
import 'features/shifts/providers/shifts_provider.dart';
import 'features/shifts/providers/shift_assign_provider.dart';
import 'features/shifts/providers/lookup_provider.dart';
import 'features/dashboard/providers/admin_provider.dart';
import 'features/devices/providers/devices_provider.dart';
import 'features/faqs/providers/faqs_provider.dart';
import 'features/notes/providers/notes_provider.dart';
import 'features/tasks/providers/tasks_provider.dart';
import 'features/tasktype/providers/task_type_provider.dart';
import 'features/users/providers/users_provider.dart';
import 'features/notifications/providers/notifications_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await enableLocationOnStart();
  runApp(
    MultiProvider(
      providers: [
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

        ChangeNotifierProvider(create: (_) => ImagePickerProvider()),
        // others
        ChangeNotifierProvider(create: (_) => UsersProvider()),
        ChangeNotifierProvider(create: (_) => DevicesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
        ChangeNotifierProvider(create: (_) => FaqsProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TaskTypeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> enableLocationOnStart() async {
  bool serviceEnabled;
  LocationPermission permission;

  // 1. Check if location services are enabled
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Cannot turn on automatically → prompt user
    await Geolocator.openLocationSettings();
    return;
  }

  // 2. Check for permission
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions still denied
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are permanently denied, open app settings
    await Geolocator.openAppSettings();
    return;
  }

  // 3. At this point, location is ON and permission granted
  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
