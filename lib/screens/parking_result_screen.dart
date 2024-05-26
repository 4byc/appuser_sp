import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'home_screen.dart';

class ParkingResultScreen extends StatefulWidget {
  final String vehicleId;
  final String slotId;
  final String slotClass;
  final int entryTime;

  ParkingResultScreen({
    required this.vehicleId,
    required this.slotId,
    required this.slotClass,
    required this.entryTime,
  });

  @override
  _ParkingResultScreenState createState() => _ParkingResultScreenState();
}

class _ParkingResultScreenState extends State<ParkingResultScreen> {
  int? exitTime;
  double? totalCost;

  Future<void> completeParking() async {
    setState(() {
      exitTime = DateTime.now().millisecondsSinceEpoch;
      totalCost = calculateParkingFee(widget.entryTime, exitTime!);
    });

    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    // Add to exits collection
    await _firestore.collection('exits').add({
      'class': widget.slotClass,
      'exitTime': exitTime,
      'id': widget.slotId,
      'parkingDuration': exitTime! - widget.entryTime,
      'parkingFee': totalCost,
      'vehicleId': widget.vehicleId,
    });

    // Clean the parking slot
    DocumentSnapshot slotDoc =
        await _firestore.collection('parkingSlots').doc(widget.slotClass).get();
    var slots = List.from(slotDoc['slots']);
    var slot = slots.firstWhere((slot) => slot['id'] == widget.slotId);
    slot['isFilled'] = false;
    slot['vehicleId'] = null;
    slot['entryTime'] = null;
    await _firestore
        .collection('parkingSlots')
        .doc(widget.slotClass)
        .update({'slots': slots});

    // Add to payments collection
    await _firestore.collection('payments').add({
      'paymentAmount': totalCost,
      'paymentTime': exitTime,
      'slotId': widget.slotId,
      'status': 'Success',
      'vehicleId': widget.vehicleId,
    });
  }

  double calculateParkingFee(int entry, int exit) {
    const double ratePerHour = 5.0; // Example rate per hour
    final duration = Duration(milliseconds: exit - entry);
    final hours = duration.inHours + (duration.inMinutes % 60) / 60.0;
    return hours * ratePerHour;
  }

  @override
  Widget build(BuildContext context) {
    final entryDateTime = DateTime.fromMillisecondsSinceEpoch(widget.entryTime);
    final entryTimeFormatted =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(entryDateTime);

    return Scaffold(
      appBar: AppBar(title: Text('Parking Result')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vehicle parked at: ${widget.slotId}',
                      style: TextStyle(fontSize: 20)),
                  SizedBox(height: 8),
                  Text('Class: ${widget.slotClass}',
                      style: TextStyle(fontSize: 20)),
                  SizedBox(height: 8),
                  Text('Entry Time: $entryTimeFormatted',
                      style: TextStyle(fontSize: 20)),
                ],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: completeParking,
              child: Text('Complete Parking and Calculate Cost'),
            ),
            if (totalCost != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  children: [
                    Text('Total cost: \$${totalCost!.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 24)),
                    SizedBox(height: 20),
                    Text('Parking Information',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text('Vehicle Class: ${widget.slotClass}',
                        style: TextStyle(fontSize: 16)),
                    Text('Entry Time: $entryTimeFormatted',
                        style: TextStyle(fontSize: 16)),
                    Text(
                        'Exit Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(exitTime!))}',
                        style: TextStyle(fontSize: 16)),
                    Text('Parking Fee: \$${totalCost!.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 16)),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => HomeScreen()),
                          (route) => false,
                        );
                      },
                      child: Text('Continue Payment'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
