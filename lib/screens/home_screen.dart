import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'parking_result_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatelessWidget {
  static const String routeName = '/home';

  Future<int?> getLatestVehicleId(BuildContext context) async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;

      // Initialize with a very small vehicle ID
      int? latestVehicleId;
      int maxVehicleId = -1;

      // Query each document in the 'parkingSlots' collection (A, B, C)
      for (String slotClass in ['A', 'B', 'C']) {
        DocumentSnapshot slotSnapshot = await _firestore
            .collection('parkingSlots')
            .doc(slotClass)
            .get();

        // Get the data as a Map<String, dynamic>
        Map<String, dynamic>? data = slotSnapshot.data() as Map<String, dynamic>?;

        // Ensure data is not null and contains the 'slots' field
        if (data != null && data.containsKey('slots')) {
          // Get the slots field from the document data
          List<dynamic>? slots = data['slots'] as List<dynamic>?;

          // Check if slots is not null and not empty
          if (slots != null && slots.isNotEmpty) {
            // Iterate through slots to find the highest vehicleId
            for (var slot in slots) {
              dynamic vehicleId = slot['vehicleId'];
              if (vehicleId != null) {
                if (vehicleId is int) {
                  // If vehicleId is an integer, compare directly
                  if (vehicleId > maxVehicleId) {
                    maxVehicleId = vehicleId;
                    latestVehicleId = vehicleId;
                  }
                } else if (vehicleId is String) {
                  // If vehicleId is a string, parse it to integer
                  int? parsedVehicleId = int.tryParse(vehicleId);
                  if (parsedVehicleId != null) {
                    if (parsedVehicleId > maxVehicleId) {
                      maxVehicleId = parsedVehicleId;
                      latestVehicleId = parsedVehicleId;
                    }
                  }
                }
              }
            }
          }
        }
      }

      return latestVehicleId;
    } catch (e) {
      print('Error retrieving latest vehicle ID: $e');
      return null;
    }
  }

  Future<void> findParking(BuildContext context) async {
  String? slotId;
  String? slotClass;
  int? entryTime;

  try {
    final int? vehicleId = await getLatestVehicleId(context);

    if (vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No vehicle data found.')),
      );
      return;
    }

    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final QuerySnapshot snapshot = await _firestore.collection('parkingSlots').get();

    // Find the slot where the vehicleId is found
    for (final doc in snapshot.docs) {
      final slots = doc['slots'] as List<dynamic>;
      final vehicleSlot = slots.firstWhere(
        (slot) => slot['vehicleId'] == vehicleId,
        orElse: () => null,
      );
      
      if (vehicleSlot != null) {
        slotClass = doc.id;
        slotId = vehicleSlot['id'] as String?;
        entryTime = vehicleSlot['entryTime'] as int?;
        
        // Once the slot is found, break out of the loop
        break;
      }
    }

    if (slotClass == null || slotId == null || entryTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No slot found for the largest vehicle ID')),
      );
      return;
    }

    // Navigate to the VehicleDetailsScreen with the retrieved details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleDetailsScreen(
          vehicleId: vehicleId.toString(),
          slotId: slotId!,
          slotClass: slotClass!,
          entryTime: entryTime!,
        ),
      ),
    );

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
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Signed out successfully')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome!'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => findParking(context),
              child: Text('Find Your Parking'),
            ),
          ],
        ),
      ),
    );
  }
}


