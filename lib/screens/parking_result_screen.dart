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
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int durationInSeconds = currentTime - entryTime;
    final int durationInHours = (durationInSeconds / 3600).ceil();
    final int durationInMinutes = ((durationInSeconds % 3600) / 60).round();
    int totalCost = 0;

    switch (slotClass) {
      case 'A':
        totalCost = _calculateCost(durationInHours, 15000, 10000);
        break;
      case 'B':
        totalCost = _calculateCost(durationInHours, 10000, 8000);
        break;
      case 'C':
        totalCost = _calculateCost(durationInHours, 5000, 3000);
        break;
      default:
        print("Vehicle class not recognized.");
    }

    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final DocumentSnapshot fineDoc =
        await _firestore.collection('fines').doc(vehicleId).get();
    int fine = 0;
    if (fineDoc.exists) {
      final fineData = fineDoc.data() as Map<String, dynamic>;
      fine = fineData['fine'] as int;
    }

    return {
      'totalCost': totalCost,
      'durationInHours': durationInHours,
      'durationInMinutes': durationInMinutes,
      'fine': fine,
      'finalAmount': totalCost + fine,
    };
  }

  int _calculateCost(int hours, int firstHourCost, int subsequentHourCost) {
    if (hours <= 0) return 0;
    return firstHourCost + ((hours - 1) * subsequentHourCost);
  }

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> findAndExitParking(
      BuildContext context, String vehicleId) async {
    try {
      int parsedVehicleId = int.parse(vehicleId);

      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      final QuerySnapshot snapshot =
          await _firestore.collection('parkingSlots').get();

      for (final doc in snapshot.docs) {
        final slots = doc['slots'] as List<dynamic>;
        for (var i = 0; i < slots.length; i++) {
          final slot = slots[i];
          if (slot['vehicleId'] == parsedVehicleId) {
            slots[i]['entryTime'] = null;
            slots[i]['vehicleId'] = null;
            slots[i]['isFilled'] = false;
          }
        }
        await _firestore
            .collection('parkingSlots')
            .doc(doc.id)
            .update({'slots': slots});
      }
      Navigator.pop(context);
    } catch (e) {
      print('Error: $e');
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> calculateAndStorePayment(
      BuildContext context, String vehicleId) async {
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      final int parsedVehicleId = int.parse(vehicleId);

      final Map<String, dynamic> paymentDetails = await calculatePayment();
      final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _firestore.collection('payment').add({
        'vehicleId': parsedVehicleId,
        'slotId': slotId,
        'slotClass': slotClass,
        'entryTime': entryTime,
        'exitTime': currentTime,
        'duration':
            '${paymentDetails['durationInHours']} hours ${paymentDetails['durationInMinutes']} minutes',
        'totalCost': paymentDetails['totalCost'],
        'fine': paymentDetails['fine'],
        'finalAmount': paymentDetails['finalAmount'],
      });

      showDialog(
        context: _scaffoldKey.currentContext!,
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
            content: Text(
                'Your payment was successful. Total Amount: Rp ${paymentDetails['finalAmount']} (Fine: Rp ${paymentDetails['fine']})'),
            actions: [
              TextButton(
                onPressed: () {
                  findAndExitParking(context, vehicleId);
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
              Text(
                  'Total Time: ${paymentDetails['durationInHours']} hours ${paymentDetails['durationInMinutes']} minutes'),
              SizedBox(height: 8),
              Text(
                'Rp ${paymentDetails['totalCost']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 8),
              if (paymentDetails['fine'] > 0)
                Text(
                  'Fine: Rp ${paymentDetails['fine']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              SizedBox(height: 8),
              Text(
                'Total Amount: Rp ${paymentDetails['finalAmount']}',
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
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                calculateAndStorePayment(context, vehicleId);
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> checkForMessages(BuildContext context) async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(vehicleId).get();

    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('message')) {
        final String message = data['message'];
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Message from Admin'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No new messages')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No new messages')),
      );
    }
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
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {
              checkForMessages(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('parkingSlots')
                .doc(vehicleId)
                .get(),
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
                                backgroundColor: Colors.blue,
                                disabledForegroundColor:
                                    Colors.white.withOpacity(0.38),
                                disabledBackgroundColor:
                                    Colors.white.withOpacity(0.12),
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
