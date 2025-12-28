import 'package:flutter/material.dart';
import 'package:kabinet/shared/models/base_model.dart';
import 'package:kabinet/shared/models/profile.dart';
import 'package:kabinet/shared/models/room.dart';

/// Бронирование кабинета (блокировка для мероприятий)
class Booking extends BaseModel {
  final String institutionId;
  final String createdBy;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? description;

  /// Joined data
  final Profile? creator;
  final List<Room> rooms;

  const Booking({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.createdBy,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.description,
    this.creator,
    this.rooms = const [],
  });

  /// Длительность в минутах
  int get durationMinutes {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    return endMinutes - startMinutes;
  }

  /// Названия кабинетов через запятую
  String get roomNames => rooms.map((r) => r.displayName).join(', ');

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Парсинг времени из строки "HH:MM:SS"
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    // Парсинг кабинетов из booking_rooms join
    List<Room> parseRooms(dynamic bookingRooms) {
      if (bookingRooms == null) return [];
      if (bookingRooms is! List) return [];

      return bookingRooms
          .where((br) => br['rooms'] != null)
          .map((br) => Room.fromJson(br['rooms'] as Map<String, dynamic>))
          .toList();
    }

    return Booking(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      institutionId: json['institution_id'] as String,
      createdBy: json['created_by'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: parseTime(json['start_time'] as String),
      endTime: parseTime(json['end_time'] as String),
      description: json['description'] as String?,
      creator: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
      rooms: parseRooms(json['booking_rooms']),
    );
  }

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'created_by': createdBy,
        'date': date.toIso8601String().split('T').first,
        'start_time':
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'end_time':
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'description': description,
      };

  Booking copyWith({
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? description,
    List<Room>? rooms,
  }) =>
      Booking(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        createdBy: createdBy,
        date: date ?? this.date,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        description: description ?? this.description,
        creator: creator,
        rooms: rooms ?? this.rooms,
      );
}
