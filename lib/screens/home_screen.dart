import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'parking_result_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/home';

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? username;

  @override
  void initState() {
    super.initState();
    fetchUsername();
  }

  Future<void> fetchUsername() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final User? user = authService.currentUser;
      if (user != null) {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            username = userDoc['username'];
          });
        }
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
  }

  Future<int?> getLatestVehicleId(BuildContext context) async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;

      int? latestVehicleId;
      int maxVehicleId = -1;

      for (String slotClass in ['A', 'B', 'C']) {
        DocumentSnapshot slotSnapshot =
            await _firestore.collection('parkingSlots').doc(slotClass).get();

        Map<String, dynamic>? data =
            slotSnapshot.data() as Map<String, dynamic>?;

        if (data != null && data.containsKey('slots')) {
          List<dynamic>? slots = data['slots'] as List<dynamic>?;

          if (slots != null && slots.isNotEmpty) {
            for (var slot in slots) {
              dynamic vehicleId = slot['vehicleId'];
              if (vehicleId != null) {
                if (vehicleId is int) {
                  if (vehicleId > maxVehicleId) {
                    maxVehicleId = vehicleId;
                    latestVehicleId = vehicleId;
                  }
                } else if (vehicleId is String) {
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

  Future<bool> isParkingFull(String vehicleClass) async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      final DocumentSnapshot snapshot =
          await _firestore.collection('parkingSlots').doc(vehicleClass).get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        final List<dynamic> slots = data?['slots'] ?? [];
        final filledSlots =
            slots.where((slot) => slot['isFilled'] == true).length;
        final totalSlots = slots.length;

        return filledSlots >= totalSlots;
      }
    } catch (e) {
      print('Error checking parking status: $e');
    }
    return false;
  }

  Future<void> findParking(BuildContext context) async {
    String? slotId;
    String? slotClass;
    int? entryTime;
    String? ImgURL;

    try {
      final int? vehicleId = await getLatestVehicleId(context);

      if (vehicleId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No vehicle data found.')),
        );
        return;
      }

      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      final QuerySnapshot snapshot =
          await _firestore.collection('parkingSlots').get();

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
          ImgURL = vehicleSlot['ImgURL'] as String?;
          break;
        }
      }

      if (slotClass == null || slotId == null || entryTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No slot found for the largest vehicle ID')),
        );
        return;
      }

      // Check if the parking lot is full for the detected class
      final bool isFull = await isParkingFull(slotClass);
      if (isFull) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text(
                'Parking Full',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              content: Text(
                  'The parking lot is full for your vehicle class. Please turn back.\nVehicle ID: $vehicleId'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    moveToExitedAndRecordPayment(vehicleId);
                  },
                  child: const Text('Exit'),
                ),
              ],
            );
          },
        );

        // Move the waiting vehicle to 'Hold' status
        var detectionDoc = await _firestore
            .collection('detections')
            .where('VehicleID', isEqualTo: vehicleId)
            .get();
        if (detectionDoc.docs.isNotEmpty) {
          await _firestore
              .collection('detections')
              .doc(detectionDoc.docs.first.id)
              .update({'status': 'Hold'});
        }
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleDetailsScreen(
            vehicleId: vehicleId.toString(),
            slotId: slotId!,
            slotClass: slotClass!,
            entryTime: entryTime!,
            ImgURL: ImgURL!,
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

  Future<void> moveToExitedAndRecordPayment(int vehicleId) async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    // Find the detection document with status 'Hold'
    final QuerySnapshot detectionSnapshot = await _firestore
        .collection('detections')
        .where('VehicleID', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'Hold')
        .get();

    if (detectionSnapshot.docs.isNotEmpty) {
      final detectionDoc = detectionSnapshot.docs.first;
      final detectionData = detectionDoc.data() as Map<String, dynamic>;

      // Move to exited vehicles
      await _firestore.collection('exitedVehicles').add(detectionData);

      // Record a payment with cancellation info
      await _firestore.collection('payment').add({
        'vehicleId': vehicleId,
        'slotClass': detectionData['class'],
        'entryTime': detectionData['time'],
        'exitTime': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'duration': 0, // No duration since it was canceled
        'totalCost': 0,
        'fine': 0,
        'finalAmount': 0,
        'status': 'Cancelled',
      });

      // Remove the detection document
      await _firestore.collection('detections').doc(detectionDoc.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Home',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),
            onPressed: () async {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              await authService.signOut(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Signed out successfully')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    username != null ? 'Welcome, $username!' : 'Welcome!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => findParking(context),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        disabledForegroundColor: Colors.white.withOpacity(0.38),
                        disabledBackgroundColor: Colors.white.withOpacity(0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Find Your Parking',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
