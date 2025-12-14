import 'package:cloud_firestore/cloud_firestore.dart';

class Wallet {
  final String userId;
  final double totalSpent;
  final double availableDiscount;
  final List<GiftVoucher> giftVouchers;

  Wallet({
    required this.userId,
    required this.totalSpent,
    required this.availableDiscount,
    required this.giftVouchers,
  });

  factory Wallet.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Wallet(
      userId: doc.id,
      totalSpent: (data['totalSpent'] ?? 0).toDouble(),
      availableDiscount: (data['availableDiscount'] ?? 0).toDouble(),
      giftVouchers:
          (data['giftVouchers'] as List<dynamic>? ?? [])
              .map((voucher) => GiftVoucher.fromMap(voucher))
              .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalSpent': totalSpent,
      'availableDiscount': availableDiscount,
      'giftVouchers': giftVouchers.map((voucher) => voucher.toMap()).toList(),
    };
  }
}

class GiftVoucher {
  final String id;
  final String senderId;
  final String receiverId;
  final double amount;
  final bool isApproved;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final bool isUsed;

  GiftVoucher({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.isApproved,
    required this.createdAt,
    this.approvedAt,
    required this.isUsed,
  });

  factory GiftVoucher.fromMap(Map<String, dynamic> map) {
    return GiftVoucher(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      isApproved: map['isApproved'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      approvedAt:
          map['approvedAt'] != null
              ? (map['approvedAt'] as Timestamp).toDate()
              : null,
      isUsed: map['isUsed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'amount': amount,
      'isApproved': isApproved,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'isUsed': isUsed,
    };
  }
}
