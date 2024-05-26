import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'parking_result_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatelessWidget {
  static const String routeName = '/home';

  Future<void> findParking(BuildContext context) async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      Provider.of<AuthService>(context, listen: false);
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No user is currently signed in.')),
        );
        return;
      }

      // Fetch the user's vehicle ID
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print('User document does not exist');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No vehicle data found for the user.')),
        );
        return;
      }

      var userData = userDoc.data() as Map<String, dynamic>;
      if (!userData.containsKey('vehicleId') || userData['vehicleId'].isEmpty) {
        print('User document does not contain vehicleId');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No vehicle data found for the user.')),
        );
        return;
      }

      String vehicleId = userData['vehicleId'];
      print('Vehicle ID: $vehicleId');

      // Retrieve parking slots
      QuerySnapshot parkingSlotsSnapshot =
          await _firestore.collection('parkingSlots').get();
      print(
          'Parking slots snapshot retrieved: ${parkingSlotsSnapshot.size} documents found.');

      bool slotFound = false;
      for (var slotClassDoc in parkingSlotsSnapshot.docs) {
        var slotClass = slotClassDoc.id;
        var slots = List.from(slotClassDoc['slots']);
        var availableSlot =
            slots.firstWhere((slot) => !slot['isFilled'], orElse: () => null);

        if (availableSlot != null) {
          slotFound = true;
          // Update the slot with the user's vehicle data
          availableSlot['isFilled'] = true;
          availableSlot['vehicleId'] = vehicleId;
          availableSlot['entryTime'] = DateTime.now().millisecondsSinceEpoch;

          // Update Firestore
          await _firestore
              .collection('parkingSlots')
              .doc(slotClass)
              .update({'slots': slots});

          print('Updated parking slot: $availableSlot');

          // Navigate to the result screen with correct parameters
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParkingResultScreen(
                vehicleId: vehicleId,
                slotId: availableSlot['id'],
                slotClass: slotClass,
                entryTime: availableSlot['entryTime'],
              ),
            ),
          );
          break;
        }
      }

      if (!slotFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No available slots')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
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
