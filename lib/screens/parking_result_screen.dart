import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleDetailsScreen extends StatelessWidget {
  final String vehicleId;
  final String slotId;
  final String slotClass;
  final int entryTime;
  final String ImgURL;

  VehicleDetailsScreen({
    required this.vehicleId,
    required this.slotId,
    required this.slotClass,
    required this.entryTime,
    required this.ImgURL,
  });

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<Map<String, dynamic>> calculatePayment() async {
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Current time in seconds
    final int durationInSeconds = currentTime - entryTime;
    final double durationInHours = durationInSeconds / 3600.0;
    int costPerHour;

    switch (slotClass) {
      case 'A':
        costPerHour = 15000;
        break;
      case 'B':
        costPerHour = 10000;
        break;
      case 'C':
        costPerHour = 5000;
        break;
      default:
        costPerHour = 0;
    }

    final int totalCost = (durationInHours * costPerHour).ceil();

    return {
      'totalCost': totalCost,
      'durationInHours': durationInHours,
    };
  }

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
      // Show error using ScaffoldMessenger with GlobalKey
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> calculateAndStorePayment(BuildContext context, String vehicleId) async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      final int parsedVehicleId = int.parse(vehicleId); // Convert the string to int

      final Map<String, dynamic> paymentDetails = await calculatePayment();
      final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000; // Current time in seconds

      // Store payment information in Firestore
      await _firestore.collection('payment').add({
        'vehicleId': parsedVehicleId,
        'slotId': slotId,
        'slotClass': slotClass,
        'entryTime': entryTime,
        'exitTime': currentTime,
        'duration': paymentDetails['durationInHours'],
        'totalCost': paymentDetails['totalCost'],
      });

      // Show payment success dialog
      showDialog(
        context: _scaffoldKey.currentContext!, // Use stored context
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Payment Successful',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              ),
            content: const Text('Your payment was successful.'),
            actions: [
              TextButton(
                onPressed: () {
                  findAndExitParking(context, vehicleId); // Trigger the exit process
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text('Exit'),
              ),
            ],
          );
        },
      );

    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> showPaymentDialog(BuildContext context) async {
    final Map<String, dynamic> paymentDetails = await calculatePayment();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Payment Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
            ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Time: ${paymentDetails['durationInHours'].toStringAsFixed(2)} hours'),
              SizedBox(height: 8),
              Text(
                'Rp ${paymentDetails['totalCost']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                calculateAndStorePayment(context, vehicleId); // Proceed with payment
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'Vehicle Details',
          style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Background Image using Container
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Foreground content
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('parkingSlots').doc(vehicleId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else {
                return Center(
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
                                Text(
                                  'Park your vehicle in $slotId',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Slot Class: $slotClass'),
                                const SizedBox(height: 8),
                                Text(
                                  'Entry Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(entryTime * 1000).toLocal())}',
                                ),
                                const SizedBox(height: 8),
                                const Text('Location:'),
                                const SizedBox(height: 8),
                                // Display the image using NetworkImage
                                Image.network(ImgURL),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                showPaymentDialog(context);
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.blue, disabledForegroundColor: Colors.white.withOpacity(0.38), disabledBackgroundColor: Colors.white.withOpacity(0.12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Payment',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
