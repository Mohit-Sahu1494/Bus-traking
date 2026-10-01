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

class NotificationSettings {
  NotificationSettings({
    this.busApproaching = true,
    this.busArrived = true,
    this.stopSkipped = true,
    this.tripEnded = true,
    this.paused = true,
  });

  final bool busApproaching;
  final bool busArrived;
  final bool stopSkipped;
  final bool tripEnded;
  final bool paused;

  factory NotificationSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return NotificationSettings();
    return NotificationSettings(
      busApproaching: json['busApproaching'] as bool? ?? true,
      busArrived: json['busArrived'] as bool? ?? true,
      stopSkipped: json['stopSkipped'] as bool? ?? true,
      tripEnded: json['tripEnded'] as bool? ?? true,
      paused: json['paused'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'busApproaching': busApproaching,
        'busArrived': busArrived,
        'stopSkipped': stopSkipped,
        'tripEnded': tripEnded,
        'paused': paused,
      };

  NotificationSettings copyWith({
    bool? busApproaching,
    bool? busArrived,
    bool? stopSkipped,
    bool? tripEnded,
    bool? paused,
  }) {
    return NotificationSettings(
      busApproaching: busApproaching ?? this.busApproaching,
      busArrived: busArrived ?? this.busArrived,
      stopSkipped: stopSkipped ?? this.stopSkipped,
      tripEnded: tripEnded ?? this.tripEnded,
      paused: paused ?? this.paused,
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
    NotificationSettings? notificationSettings,
  }) : notificationSettings = notificationSettings ?? NotificationSettings();

  final String id;
  final String name;
  final String email;
  final String? enrollmentNumber;
  final StopInfo? pickupStop;
  final bool isEmailVerified;
  final NotificationSettings notificationSettings;

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
      notificationSettings: NotificationSettings.fromJson(
        json['notificationSettings'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        if (enrollmentNumber != null) 'enrollmentNumber': enrollmentNumber,
        if (pickupStop != null)
          'pickupStop': {
            'id': pickupStop!.id,
            'name': pickupStop!.name,
            'code': pickupStop!.code,
            'latitude': pickupStop!.latitude,
            'longitude': pickupStop!.longitude,
          },
        'isEmailVerified': isEmailVerified,
        'notificationSettings': notificationSettings.toJson(),
      };
}
