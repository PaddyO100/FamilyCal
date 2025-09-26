/// Feature flags for Firebase integrations.
///
/// Keep `cloudFunctionsEnabled` false while running on the free Spark plan
/// to avoid calling Cloud Functions endpoints that require a paid tier.
const bool cloudFunctionsEnabled = false;
