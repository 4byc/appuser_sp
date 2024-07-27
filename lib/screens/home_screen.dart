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

      // Fetch the highest vehicle ID from detections
      QuerySnapshot detectionsSnapshot =
          await _firestore.collection('detections').get();
      for (var doc in detectionsSnapshot.docs) {
        int vehicleId = int.parse(doc['VehicleID'].toString());

        // Check if this vehicle ID is marked as canceled in payments
        bool isCanceled = false;
        QuerySnapshot paymentsSnapshot = await _firestore
            .collection('payments')
            .where('vehicleId', isEqualTo: vehicleId)
            .where('status', isEqualTo: 'Canceled')
            .get();

        if (paymentsSnapshot.docs.isNotEmpty) {
          isCanceled = true;
        }

        if (vehicleId > maxVehicleId && !isCanceled) {
          maxVehicleId = vehicleId;
          latestVehicleId = vehicleId;
        }
      }

      print('Latest Vehicle ID from detections: $latestVehicleId');
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

      bool slotFound = false;
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

          print('Slot found: $slotId, $slotClass, $entryTime, $ImgURL');

          slotFound = true;
          break;
        }
      }

      if (!slotFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No slot found for the latest vehicle ID.')),
        );
        await _notifyUserTurnBack(context, vehicleId);
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

  Future<void> _notifyUserTurnBack(BuildContext context, int vehicleId) async {
    // Store the canceled payment information
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    await _firestore.collection('payments').add({
      'vehicleId': vehicleId,
      'status': 'Canceled',
      'time': DateTime.now().millisecondsSinceEpoch,
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TurnBackScreen(vehicleId: vehicleId),
      ),
    );
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
          // Foreground content
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

class TurnBackScreen extends StatelessWidget {
  final int vehicleId;

  TurnBackScreen({required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Parking Full',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sorry, the parking lot is full.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Vehicle ID: $vehicleId',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Go back to the previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Exit',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
