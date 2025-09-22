import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/task.dart';

class TaskRepository {
  TaskRepository(FirebaseFirestore firestore)
      : _collection = firestore.collection('tasks');

  final CollectionReference<Map<String, dynamic>> _collection;

  Stream<List<HouseholdTask>> watchHouseholdTasks(String householdId) {
    return _collection
        .where('householdId', isEqualTo: householdId)
        .orderBy('isCompleted')
        .orderBy('dueDate')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HouseholdTask.fromFirestore(doc))
              .toList(),
        );
  }

  Future<String> createTask(HouseholdTask task) async {
    final doc = task.id.isEmpty ? _collection.doc() : _collection.doc(task.id);
    final payload = task.copyWith(
      id: doc.id,
      createdAt: task.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await doc.set(payload.toJson());
    return doc.id;
  }

  Future<void> updateTask(HouseholdTask task) async {
    await _collection.doc(task.id).set(
          task.copyWith(updatedAt: DateTime.now()).toJson(),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteTask(String taskId) async {
    await _collection.doc(taskId).delete();
  }
}
