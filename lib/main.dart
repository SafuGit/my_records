import 'package:flutter/material.dart';
import 'package:my_records/screens/dashboard_screen.dart';
import 'package:my_records/services/rec_sync_manager.dart';

final RecSyncManager syncManager = RecSyncManager();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await syncManager.initialize(
    deviceId: 'device_local',
    authId: 'local_user',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Navigate to DashboardScreen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white, // button background
            foregroundColor: Colors.black, // text & icon color
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: const Text(
            'Go to Dashboard Screen',
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
