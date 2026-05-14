class UserAuditLogEntry {
  const UserAuditLogEntry({
    required this.id,
    required this.action,
    required this.actorUserId,
    required this.actorUsername,
    required this.targetUserId,
    required this.targetUsername,
    required this.details,
    required this.createdAt,
  });

  final int id;
  final String action;
  final int? actorUserId;
  final String? actorUsername;
  final int? targetUserId;
  final String? targetUsername;
  final String? details;
  final DateTime createdAt;
}
