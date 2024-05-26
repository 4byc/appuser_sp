import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class VehicleDetailsScreen extends StatelessWidget {
  final String vehicleId;
  final String slotId;
  final String slotClass;
  final int entryTime;

  VehicleDetailsScreen({
    required this.vehicleId,
    required this.slotId,
    required this.slotClass,
    required this.entryTime,
  });

  Future<void> findAndExitParking(BuildContext context, String vehicleId) async {
    try {
      int parsedVehicleId = int.parse(vehicleId); // Convert the string to int

      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      final QuerySnapshot snapshot = await _firestore.collection('parkingSlots').get();

      // Iterate through each document in the collection
      for (final doc in snapshot.docs) {
        final slots = doc['slots'] as List<dynamic>;
        // Iterate through each slot in the document
        for (var i = 0; i < slots.length; i++) {
          final slot = slots[i];
          // Check if the slot contains the vehicle ID
          if (slot['vehicleId'] == parsedVehicleId) { // Use parsedVehicleId
            // Update the slot data
            slots[i]['entryTime'] = null;
            slots[i]['vehicleId'] = null;
            slots[i]['isFilled'] = false;
          }
        }
        // Update the document in Firestore
        await _firestore.collection('parkingSlots').doc(doc.id).update({'slots': slots});
      }

      // Navigate back to the previous screen
      Navigator.pop(context);
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Vehicle Details')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                        'Entry Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(entryTime * 1000).toLocal())}',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    findAndExitParking(context, vehicleId); // Pass vehicleId as string
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
