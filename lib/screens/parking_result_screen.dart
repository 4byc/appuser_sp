import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VehicleDetailsScreen extends StatelessWidget {
  final String vehicleId;
  final String slotId;
  final String slotClass;
  final int entryTime;

  VehicleDetailsScreen(required String vehicleId, {
    required this.vehicleId,
    required this.slotId,
    required this.slotClass,
    required this.entryTime,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Vehicle Details')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Align widgets to the center horizontally
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vehicle ID: $vehicleId'),
                      SizedBox(height: 8),
                      Text('Slot ID: $slotId'),
                      SizedBox(height: 8),
                      Text('Slot Class: $slotClass'),
                      SizedBox(height: 8),
                      Text(
                        'Entry Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(entryTime))}',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Center( // Center widget added here
                child: ElevatedButton(
                  onPressed: () {
                    // Implement exit logic here
                  },
                  child: Text('Exit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
