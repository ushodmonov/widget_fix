import 'package:flutter/material.dart';

enum SpendingCategory {
  groceries('Groceries', Icons.shopping_basket_rounded),
  transport('Transport', Icons.directions_car_rounded),
  dining('Dining', Icons.restaurant_rounded),
  subscriptions('Subscriptions', Icons.repeat_rounded),
  shopping('Shopping', Icons.shopping_bag_rounded),
  travel('Travel', Icons.flight_rounded),
  income('Income', Icons.south_west_rounded);

  const SpendingCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Fits under a chart bar.
  String get shortName => switch (this) {
    groceries => 'Food',
    transport => 'Rides',
    subscriptions => 'Subs',
    shopping => 'Shop',
    _ => label,
  };
}

class Transaction {
  const Transaction({
    required this.id,
    required this.merchant,
    required this.note,
    required this.category,
    required this.amount,
    required this.date,
  });

  final int id;
  final String merchant;
  final String note;
  final SpendingCategory category;

  /// In cents: positive for money in, negative for money out.
  final int amount;
  final DateTime date;

  bool get isIncome => amount > 0;
}

class PaymentCard {
  const PaymentCard({
    required this.id,
    required this.name,
    required this.holder,
    required this.lastFour,
    required this.expiry,
    required this.network,
    required this.gradient,
    required this.monthlyLimit,
    required this.spentThisMonth,
    required this.isFrozen,
    required this.allowsOnlinePayments,
  });

  final int id;
  final String name;
  final String holder;
  final String lastFour;
  final String expiry;
  final String network;
  final List<Color> gradient;
  final int monthlyLimit;
  final int spentThisMonth;
  final bool isFrozen;
  final bool allowsOnlinePayments;

  PaymentCard copyWith({bool? isFrozen, bool? allowsOnlinePayments}) => PaymentCard(
    id: id,
    name: name,
    holder: holder,
    lastFour: lastFour,
    expiry: expiry,
    network: network,
    gradient: gradient,
    monthlyLimit: monthlyLimit,
    spentThisMonth: spentThisMonth,
    isFrozen: isFrozen ?? this.isFrozen,
    allowsOnlinePayments: allowsOnlinePayments ?? this.allowsOnlinePayments,
  );
}

class DaySection {
  const DaySection({required this.day, required this.transactions});

  final DateTime day;
  final List<Transaction> transactions;

  int get total => transactions.fold(0, (sum, transaction) => sum + transaction.amount);
}

class CategoryTotal {
  const CategoryTotal({required this.category, required this.total});

  final SpendingCategory category;
  final int total;
}
