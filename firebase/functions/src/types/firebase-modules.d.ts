declare module 'firebase-admin' {
  function admin(app?: any): any;

  namespace admin {
    function initializeApp(options?: unknown): void;
    function messaging(appName?: string): any;
    function firestore(appName?: string): any;

    namespace firestore {
      class Timestamp {
        static fromDate(date: Date): Timestamp;
        static now(): Timestamp;
        toDate(): Date;
      }

      class FieldValue {
        static serverTimestamp(): Timestamp;
        static delete(): unknown;
      }
    }
  }

  export = admin;
}

declare module 'firebase-functions' {
  const functions: any;
  export = functions;
}
