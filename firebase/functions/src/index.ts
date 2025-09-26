import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
admin.initializeApp();
const db = admin.firestore();

async function collectParticipantTokens(userIds: string[]): Promise<string[]> {
  const tokens = new Set<string>();
  for (const uid of userIds) {
    const snapshot = await db
      .collection('deviceTokens')
      .doc(uid)
      .collection('tokens')
      .get();
    snapshot.forEach((doc) => {
      const token = doc.data().token as string | undefined;
      if (token) {
        tokens.add(token);
      }
    });
  }
  return Array.from(tokens);
}

function formatDateKey(date: Date): string {
  const year = date.getFullYear().toString().padStart(4, '0');
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  return `${year}${month}${day}`;
}
export const scheduleEventReminders = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login erforderlich');
  }
  const calendarId = data.calendarId as string | undefined;
  const eventId = data.eventId as string | undefined;
  const reminderMinutes = data.reminderMinutes as number[] | undefined;
  if (!calendarId || !eventId || !reminderMinutes || !Array.isArray(reminderMinutes)) {
    throw new functions.https.HttpsError('invalid-argument', 'calendarId, eventId und reminderMinutes sind erforderlich.');
  }
  const eventRef = db.collection('calendars').doc(calendarId).collection('events').doc(eventId);
  const snapshot = await eventRef.get();
  if (!snapshot.exists) {
    throw new functions.https.HttpsError('not-found', 'Termin nicht gefunden.');
  }
  const eventData = snapshot.data() ?? {};
  const start = (eventData.start as admin.firestore.Timestamp).toDate();
  const householdId = eventData.householdId as string;
  const scheduleBatch = db.batch();
  reminderMinutes.forEach((minutes) => {
    const fireAt = admin.firestore.Timestamp.fromDate(new Date(start.getTime() - minutes * 60000));
    const reminderRef = db
      .collection('scheduledReminders')
      .doc(`${eventId}_${minutes}`);
    scheduleBatch.set(reminderRef, {
      calendarId,
      eventId,
      householdId,
      reminderMinutes: minutes,
      fireAt,
      sent: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
  await scheduleBatch.commit();
  return {status: 'scheduled'};
});

export const reminderWorker = functions.pubsub.schedule('* * * * *').onRun(async () => {
  const now = admin.firestore.Timestamp.now();
  const pending = await db
    .collection('scheduledReminders')
    .where('fireAt', '<=', now)
    .where('sent', '==', false)
    .limit(10)
    .get();

  const messaging = admin.messaging();
  for (const doc of pending.docs) {
    const data = doc.data();
    const calendarId = data.calendarId as string;
    const eventId = data.eventId as string;
    const eventRef = db.collection('calendars').doc(calendarId).collection('events').doc(eventId);
    const eventSnapshot = await eventRef.get();
    if (!eventSnapshot.exists) {
      await doc.ref.update({sent: true, reason: 'missing-event'});
      continue;
    }
    const eventData = eventSnapshot.data() ?? {};
    const title = eventData.title as string;
    const participantIds = (eventData.participantIds as string[]) ?? [];
    const tokens = await collectParticipantTokens(participantIds);
    if (tokens.length === 0) {
      await doc.ref.update({sent: true, reason: 'no-tokens'});
      continue;
    }
    await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: 'Erinnerung',
        body: `${title} startet in ${data.reminderMinutes} Minuten`,
      },
      data: {
        calendarId,
        eventId,
      },
    });
    await doc.ref.update({sent: true, sentAt: admin.firestore.FieldValue.serverTimestamp()});
  }
  return null;
});

export const birthdayUpdater = functions.pubsub.schedule('0 2 * * *').onRun(async () => {
  const today = new Date();
  const birthdays = await db.collection('birthdays').get();
  for (const doc of birthdays.docs) {
    const data = doc.data();
    const birthDate = (data.birthDate as admin.firestore.Timestamp | undefined)?.toDate();
    if (!birthDate) {
      continue;
    }
    let next = new Date(today.getFullYear(), birthDate.getMonth(), birthDate.getDate());
    if (next < today) {
      next = new Date(today.getFullYear() + 1, birthDate.getMonth(), birthDate.getDate());
    }
    const age = next.getFullYear() - birthDate.getFullYear();
    await doc.ref.set(
      {
        nextOccurrence: admin.firestore.Timestamp.fromDate(next),
        upcomingAge: age,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
  return null;
});

export const aggregateAvailabilities = functions.firestore
  .document('availabilities/{docId}')
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    const before = change.before.exists ? change.before.data() : null;
    const householdId = (after?.householdId as string | undefined) ?? (before?.householdId as string | undefined);
    const dateKey = (after?.dateKey as string | undefined) ?? (before?.dateKey as string | undefined);
    if (!householdId || !dateKey) {
      return null;
    }

    const snapshot = await db
      .collection('availabilities')
      .where('householdId', '==', householdId)
      .where('dateKey', '==', dateKey)
      .get();

    if (snapshot.empty) {
      await db
        .collection('availabilitySummaries')
        .doc(`${householdId}_${dateKey}`)
        .delete()
        .catch(() => null);
      return null;
    }

    let availableMembers = 0;
    let earliestStart: number | null = null;
    let latestEnd: number | null = null;

    snapshot.forEach((doc) => {
      const slots = (doc.data().slots as Array<Record<string, unknown>> | undefined) ?? [];
      if (slots.length > 0) {
        availableMembers += 1;
      }
      slots.forEach((slot) => {
        const start = Number(slot.startMinutes ?? 0);
        const end = Number(slot.endMinutes ?? 0);
        if (earliestStart === null || start < earliestStart) {
          earliestStart = start;
        }
        if (latestEnd === null || end > latestEnd) {
          latestEnd = end;
        }
      });
    });

    const payload: Record<string, unknown> = {
      householdId,
      dateKey,
      availableMembers,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (earliestStart !== null) {
      payload.earliestStartMinutes = earliestStart;
    } else {
      payload.earliestStartMinutes = admin.firestore.FieldValue.delete();
    }
    if (latestEnd !== null) {
      payload.latestEndMinutes = latestEnd;
    } else {
      payload.latestEndMinutes = admin.firestore.FieldValue.delete();
    }

    await db
      .collection('availabilitySummaries')
      .doc(`${householdId}_${dateKey}`)
      .set(payload, {merge: true});
    return null;
  });

export const taskReminderWorker = functions.pubsub.schedule('0 7 * * *').onRun(async () => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayKey = formatDateKey(today);
  const dueSnapshot = await db
    .collection('tasks')
    .where('isCompleted', '==', false)
    .where('dueDate', '<=', admin.firestore.Timestamp.fromDate(today))
    .limit(20)
    .get();

  const messaging = admin.messaging();
  for (const doc of dueSnapshot.docs) {
    const data = doc.data();
    const assignees = (data.assigneeIds as string[]) ?? [];
    if (assignees.length === 0) {
      continue;
    }
    const lastReminderKey = data.lastReminderKey as string | undefined;
    if (lastReminderKey === todayKey) {
      continue;
    }
    const tokens = await collectParticipantTokens(assignees);
    if (tokens.length === 0) {
      continue;
    }
    const title = (data.title as string) ?? 'Aufgabe';
    const dueDate = (data.dueDate as admin.firestore.Timestamp | undefined)?.toDate();
    const householdId = (data.householdId as string) ?? '';
    await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: 'Aufgabe fällig',
        body: dueDate
          ? `${title} war fällig am ${dueDate.toLocaleDateString('de-DE')}`
          : `${title} ist überfällig`,
      },
      data: {
        taskId: doc.id,
        householdId,
      },
    });
    await doc.ref.update({
      lastReminderKey: todayKey,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return null;
});

export const cleanup = functions.pubsub.schedule('30 3 * * *').onRun(async () => {
  const now = admin.firestore.Timestamp.now();
  const inviteSnapshot = await db
    .collection('invites')
    .where('expiresAt', '<', now)
    .get();
  const batch = db.batch();
  inviteSnapshot.forEach((doc) => batch.delete(doc.ref));

  const remindersSnapshot = await db
    .collection('scheduledReminders')
    .where('sent', '==', true)
    .where('fireAt', '<', admin.firestore.Timestamp.fromDate(new Date(Date.now() - 7 * 86400000)))
    .get();
  remindersSnapshot.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return null;
});
