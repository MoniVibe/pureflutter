void startPersistentGameLogSession({
  required String applicationId,
  required String gameId,
  required String mode,
  required String sessionId,
  required String sessionLabel,
  required String runId,
  required String createdAtIso,
  required Map<String, Object?> context,
}) {}

void appendPersistentGameLogLine({
  required String applicationId,
  required String gameId,
  required String mode,
  required String sessionId,
  required String updatedAtIso,
  required String jsonLine,
}) {}

String? readLatestPersistentGameLogJsonl({
  required String applicationId,
  required String gameId,
  required String mode,
}) {
  return null;
}
