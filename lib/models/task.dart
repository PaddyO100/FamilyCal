import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdTask {
  HouseholdTask({
    required this.id,
    required this.householdId,
    required this.title,
    required this.createdBy,
    this.description,
    this.dueDate,
    this.isCompleted = false,
    this.assigneeIds = const <String>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String householdId;
  final String title;
  final String createdBy;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;
  final List<String> assigneeIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory HouseholdTask.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return HouseholdTask(
      id: snapshot.id,
      householdId: data['householdId'] as String,
      title: data['title'] as String,
      createdBy: data['createdBy'] as String,
      description: data['description'] as String?,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      isCompleted: data['isCompleted'] as bool? ?? false,
      assigneeIds: (data['assigneeIds'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'householdId': householdId,
      'title': title,
      'createdBy': createdBy,
      'description': description,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'isCompleted': isCompleted,
      'assigneeIds': assigneeIds,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    }..removeWhere((key, value) => value == null);
  }

  HouseholdTask copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    List<String>? assigneeIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HouseholdTask(
      id: id ?? this.id,
      householdId: householdId,
      title: title ?? this.title,
      createdBy: createdBy,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

