import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:familycal/models/birthday.dart';
import 'package:familycal/models/household.dart';

class BirthdayTab extends StatelessWidget {
  const BirthdayTab({super.key, required this.household});

  final Household household;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('birthdays')
        .where('householdId', isEqualTo: household.id)
        .orderBy('birthDate');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) {
          return const Center(
            child: Text('Noch keine Geburtstage hinterlegt'),
          );
        }

        final birthdays = docs.map(BirthdayEntry.fromFirestore).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final birthday = birthdays[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text('${birthday.age}'),
              ),
              title: Text(birthday.name),
              subtitle: Text('Geburtstag: ${birthday.birthDate.day}.${birthday.birthDate.month}.'),
              trailing: const Icon(Icons.cake_outlined),
            );
          },
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemCount: birthdays.length,
        );
      },
    );
  }
}
