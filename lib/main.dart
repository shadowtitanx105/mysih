import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'core/database/database_helper.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/services/location_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/network_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Initialize Database
    final databaseHelper = DatabaseHelper();
    await databaseHelper.database;

    // Initialize Services
    final locationService = LocationService();
    await locationService.initialize();

    final networkService = NetworkService();
    final syncService = SyncService(databaseHelper, networkService);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(databaseHelper),
          ),
          ChangeNotifierProvider(
            create: (_) => ConnectivityProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => SyncProvider(syncService),
          ),
          Provider<DatabaseHelper>.value(value: databaseHelper),
          Provider<LocationService>.value(value: locationService),
          Provider<NetworkService>.value(value: networkService),
          Provider<SyncService>.value(value: syncService),
        ],
        child: const LoanUtilizationApp(),
      ),
    );
  } catch (e) {
    // If initialization fails, show error screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Restart app
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
