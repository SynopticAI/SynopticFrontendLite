// lib/widgets/credit_usage_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_device_manager/auth.dart';

class CreditUsageWidget extends StatelessWidget {
  final String? deviceId; // If null, shows user total; if provided, shows device total
  final bool showIcon;
  
  const CreditUsageWidget({
    Key? key,
    this.deviceId,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Auth().currentUser;
    
    if (user == null) {
      return Container(); // Don't show anything if no user
    }

    // Determine the stream based on whether we want user or device credits
    late Stream<DocumentSnapshot> stream;
    
    if (deviceId != null) {
      // Device-specific credits
      stream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId!)
          .snapshots();
    } else {
      // User total credits
      stream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildCreditDisplay(0.0, context);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final creditsUsed = (data?['totalCreditsUsed'] ?? 0.0).toDouble();
        
        return _buildCreditDisplay(creditsUsed, context);
      },
    );
  }

  Widget _buildCreditDisplay(double creditsUsed, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 18,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 8),
          ],
          Text(
            'Credit Usage: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            creditsUsed.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}