class StopInfo {
  StopInfo({
    required this.id,
    required this.name,
    this.code,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String? code;
  final double latitude;
  final double longitude;

  factory StopInfo.fromJson(Map<String, dynamic> json) {
    return StopInfo(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RouteStopInfo {
  RouteStopInfo({
    required this.id,
    required this.sequence,
    required this.latitude,
    required this.longitude,
    required this.stop,
  });

  final String id;
  final int sequence;
  final double latitude;
  final double longitude;
  final StopInfo stop;

  factory RouteStopInfo.fromJson(Map<String, dynamic> json) {
    final stopJson = json['stop'] is Map<String, dynamic>
        ? json['stop'] as Map<String, dynamic>
        : <String, dynamic>{'id': json['stop'], 'name': '', 'latitude': json['latitude'], 'longitude': json['longitude']};
    return RouteStopInfo(
      id: json['id']?.toString() ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      stop: StopInfo.fromJson(stopJson),
    );
  }
}

class WaitingCount {
  WaitingCount({
    required this.stopId,
    required this.name,
    required this.studentsWaiting,
    this.studentsSelected = 0,
  });
  final String stopId;
  final String name;
  final int studentsWaiting;
  final int studentsSelected;

  factory WaitingCount.fromJson(Map<String, dynamic> json) {
    return WaitingCount(
      stopId: json['stopId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      studentsWaiting: (json['studentsWaiting'] as num?)?.toInt() ?? 0,
      studentsSelected: (json['studentsSelected'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudentUser {
  StudentUser({
    required this.id,
    required this.name,
    required this.email,
    this.enrollmentNumber,
    this.pickupStop,
    this.isEmailVerified = false,
  });

  final String id;
  final String name;
  final String email;
  final String? enrollmentNumber;
  final StopInfo? pickupStop;
  final bool isEmailVerified;

  factory StudentUser.fromJson(Map<String, dynamic> json) {
    StopInfo? pickup;
    final raw = json['pickupStop'];
    if (raw is Map<String, dynamic> && raw['name'] != null) {
      pickup = StopInfo.fromJson(raw);
    }
    return StudentUser(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      enrollmentNumber: json['enrollmentNumber']?.toString(),
      pickupStop: pickup,
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    );
  }
}
