import 'package:flutter/painting.dart';

import 'models.dart';

/// Deterministic stub data: every launch shows the same account.
abstract final class SampleData {
  static const ownerFirstName = 'Vladimir';
  static const ownerFullName = 'Vladimir Berestnev';
  static const balance = 1248056;
  static const monthDelta = 84210;
  static const iban = 'DE89 3704 0044 0532 0130 00';

  /// The day the stubs are anchored to, so "Today" stays today in every take.
  static final today = startOfDay(DateTime.now());

  static const cards = [
    PaymentCard(
      id: 1,
      name: 'Everyday',
      holder: ownerFullName,
      lastFour: '4821',
      expiry: '09/29',
      network: 'VISA',
      gradient: [
        Color.from(alpha: 1, red: 0.36, green: 0.31, blue: 0.95),
        Color.from(alpha: 1, red: 0.13, green: 0.76, blue: 0.84),
      ],
      monthlyLimit: 300000,
      spentThisMonth: 118437,
      isFrozen: false,
      allowsOnlinePayments: true,
    ),
    PaymentCard(
      id: 2,
      name: 'Travel',
      holder: ownerFullName,
      lastFour: '0937',
      expiry: '02/28',
      network: 'Mastercard',
      gradient: [
        Color.from(alpha: 1, red: 0.98, green: 0.45, blue: 0.36),
        Color.from(alpha: 1, red: 0.93, green: 0.25, blue: 0.56),
      ],
      monthlyLimit: 500000,
      spentThisMonth: 231690,
      isFrozen: false,
      allowsOnlinePayments: true,
    ),
    PaymentCard(
      id: 3,
      name: 'Savings',
      holder: ownerFullName,
      lastFour: '7710',
      expiry: '11/30',
      network: 'VISA',
      gradient: [
        Color.from(alpha: 1, red: 0.11, green: 0.14, blue: 0.22),
        Color.from(alpha: 1, red: 0.22, green: 0.29, blue: 0.42),
      ],
      monthlyLimit: 100000,
      spentThisMonth: 9600,
      isFrozen: true,
      allowsOnlinePayments: false,
    ),
  ];

  // (days ago, hour, minute, merchant, note, category, amount in cents)
  static const List<(int, int, int, String, String, SpendingCategory, int)> _rows = [
    (0, 9, 12, 'Five Elephant', 'Flat white, croissant', .dining, -740),
    (0, 8, 31, 'BVG', 'Single ticket AB', .transport, -350),
    (0, 7, 2, 'Northwind GmbH', 'Salary, September', .income, 465000),
    (1, 20, 44, 'Uber', 'Mitte → Kreuzberg', .transport, -1480),
    (1, 19, 5, "Mustafa's Gemüse Kebap", 'Dinner', .dining, -950),
    (1, 13, 20, 'Lidl', 'Groceries', .groceries, -4318),
    (1, 10, 0, 'Spotify', 'Premium Family', .subscriptions, -1799),
    (2, 18, 37, 'Apple', 'iCloud+ 200 GB', .subscriptions, -299),
    (2, 16, 2, 'Zalando', 'Refund, order 10482', .income, 6495),
    (2, 12, 48, 'REWE', 'Groceries', .groceries, -6172),
    (3, 21, 15, 'Netflix', 'Standard plan', .subscriptions, -1399),
    (3, 17, 30, 'Decathlon', 'Running shoes', .shopping, -8999),
    (3, 8, 50, 'Deutsche Bahn', 'Berlin → Hamburg', .travel, -3790),
    (4, 19, 55, 'Lieferando', 'Sushi for two', .dining, -3460),
    (4, 14, 10, 'DM', 'Household', .groceries, -2235),
    (5, 22, 3, 'Bolt', 'Scooter ride', .transport, -420),
    (5, 11, 41, 'IKEA', 'Shelf, lamp', .shopping, -12800),
    (6, 20, 18, 'Lufthansa', 'BER → LIS', .travel, -21430),
    (6, 9, 9, 'Anna Becker', 'Split: weekend trip', .income, 12000),
    (7, 18, 26, 'Edeka', 'Groceries', .groceries, -3804),
    (7, 13, 0, 'Vapiano', 'Lunch', .dining, -1690),
    (8, 15, 47, 'Amazon', 'USB-C hub', .shopping, -4599),
    (8, 8, 15, 'BVG', 'Monthly pass', .transport, -5800),
    (9, 19, 33, 'Booking.com', 'Lisbon, 3 nights', .travel, -34200),
    (10, 12, 12, 'Lidl', 'Groceries', .groceries, -2987),
    (10, 10, 30, 'GitHub', 'Copilot', .subscriptions, -1000),
    (11, 21, 2, 'Zur Letzten Instanz', 'Dinner', .dining, -5840),
    (12, 16, 45, 'Uniqlo', 'Jacket', .shopping, -7990),
    (12, 9, 20, 'Uber', 'Airport transfer', .transport, -3160),
    (13, 18, 8, 'REWE', 'Groceries', .groceries, -5411),
    (14, 11, 11, 'Tax Office Berlin', 'Tax refund 2025', .income, 31842),
    (15, 20, 40, 'Yorck Kinos', '2 tickets', .dining, -2400),
    (16, 13, 25, 'MediaMarkt', 'Headphones', .shopping, -14900),
    (17, 8, 5, 'Flixbus', 'Berlin → Prague', .travel, -1999),
    (18, 19, 19, 'Edeka', 'Groceries', .groceries, -4763),
    (19, 10, 10, 'Notion', 'Plus plan', .subscriptions, -950),
    (20, 14, 52, 'Tier', 'Scooter ride', .transport, -380),
    (21, 20, 6, 'Burgermeister', 'Dinner', .dining, -1320),
    (22, 12, 0, 'Max Schulz', 'Rent share', .income, 41000),
    (23, 17, 17, 'Airbnb', 'Prague, 2 nights', .travel, -16800),
  ];

  static final transactions = [
    for (final (index, (daysAgo, hour, minute, merchant, note, category, amount)) in _rows.indexed)
      Transaction(
        id: index,
        merchant: merchant,
        note: note,
        category: category,
        amount: amount,
        date: DateTime(today.year, today.month, today.day - daysAgo, hour, minute),
      ),
  ];

  static final recentTransactions = transactions.take(6).toList();

  static final days = _groupedByDay();

  static final spendingByCategory = _totalledByCategory();

  static final totalSpent = spendingByCategory.fold(0, (sum, item) => sum + item.total);

  static final totalIncome = transactions
      .where((transaction) => transaction.isIncome)
      .fold(0, (sum, transaction) => sum + transaction.amount);

  static List<DaySection> _groupedByDay() {
    final byDay = <DateTime, List<Transaction>>{};
    for (final transaction in transactions) {
      byDay.putIfAbsent(startOfDay(transaction.date), () => []).add(transaction);
    }
    return [
      for (final MapEntry(key: day, value: transactions) in byDay.entries)
        DaySection(day: day, transactions: transactions..sort((a, b) => b.date.compareTo(a.date))),
    ]..sort((a, b) => b.day.compareTo(a.day));
  }

  static List<CategoryTotal> _totalledByCategory() {
    final totals = <SpendingCategory, int>{};
    for (final transaction in transactions.where((transaction) => !transaction.isIncome)) {
      totals.update(
        transaction.category,
        (total) => total - transaction.amount,
        ifAbsent: () => -transaction.amount,
      );
    }
    return [
      for (final MapEntry(key: category, value: total) in totals.entries)
        CategoryTotal(category: category, total: total),
    ]..sort((a, b) => b.total.compareTo(a.total));
  }
}

DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);
