import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_catfinder/common/math.dart';

class CatStatus {
  final DateTime time;
  final int timestamp;
  final double accuracy;
  final double latitude;
  final double longitude;
  final double speed;
  final double speed_accuracy;
  final double heading;
  final double heading_accuracy;
  final double altitude;
  final double altitude_accuracy;
  final double odometer;
  final int activity_confidence;
  final String activity_type;
  final double battery_level;
  final bool battery_is_charging;
  final String event;
  int uploaded;

  double distance;
  String name;
  String _uuid;
  DateTime _tripStarted;
  String _imgB64;
  String imgS3;
  String _image_file_path;

  String get uuid {
    return _uuid;
  }

  set uuid(String uuid) {
    this._uuid = uuid;
  }

  String get image_file_path {
    return _image_file_path;
  }

  set image_file_path(String path) {
    this._image_file_path = path;
  }

  DateTime get tripStarted {
    return _tripStarted;
  }

  set tripStarted(DateTime dt) {
    this._tripStarted = dt;
  }

  String get imgB64 {
    return _imgB64;
  }

  set imgB64(String i) {
    this._imgB64 = i;
  }

  bool isUploaded() {
    return this.uploaded != null && this.uploaded != 0;
  }

  CatStatus({
    this.time,
    this.timestamp,
    this.accuracy,
    this.latitude,
    this.longitude,
    this.speed,
    this.speed_accuracy,
    this.heading,
    this.heading_accuracy,
    this.altitude,
    this.altitude_accuracy,
    this.odometer,
    this.activity_confidence,
    this.activity_type,
    this.battery_level,
    this.battery_is_charging,
    this.event,
    this.uploaded,
  });

  // toMap creates a dynamic map for persistence.
  Map<String, dynamic> toMap() {
    /*
    'uuid': uuid,
    'name': name,
    'version': version,
    'tripStarted': tripStarted,
    'time': time.toUtc().toIso8601String(),
    'timestamp': timestamp,
    'lat': latitude.toPrecision(9),
    'long': longitude.toPrecision(9),
    'accuracy': accuracy.toPrecision(2),
    'speed': speed.toPrecision(2),
    'speed_accuracy': speed_accuracy.toPrecision(2),
    'heading': heading.toPrecision(0),
    'heading_accuracy': heading_accuracy.toPrecision(1),
    'elevation': altitude.toPrecision(2),
    'vAccuracy': altitude_accuracy.toPrecision(1),
    'notes': notesString,
    */
    // print('apppoint -> toMap: event=${event}');
    return {
      'time': time.toUtc().toIso8601String(),
      'timestamp': timestamp,
      'accuracy': accuracy?.toPrecision(2),
      'latitude': latitude?.toPrecision(9),
      'longitude': longitude?.toPrecision(9),
      'speed': speed?.toPrecision(2),
      'speed_accuracy': speed_accuracy?.toPrecision(2),
      'heading': heading?.toPrecision(0),
      'heading_accuracy': heading_accuracy?.toPrecision(0),
      'altitude': altitude?.toPrecision(2),
      'altitude_accuracy': altitude_accuracy?.toPrecision(1),
      'odometer': odometer?.floorToDouble(),
      'activity_confidence': activity_confidence,
      'activity_type': activity_type,
      'battery_level': battery_level?.toPrecision(2),
      'battery_is_charging': battery_is_charging ? 1 : 0,
      'event': event,
      'image_file_path': image_file_path,
      // 'uploaded': uploaded,
    };
  }

  /// Converts the supplied [Map] to an instance of the [Position] class.
  static CatStatus fromMap(dynamic message) {
    if (message == null) {
      return null;
    }

    final Map<dynamic, dynamic> appMap = message;

    if (!appMap.containsKey('latitude')) {
      throw ArgumentError.value(appMap, 'appMap',
          'The supplied map doesn\'t contain the mandatory key `latitude`.');
    }

    if (!appMap.containsKey('longitude')) {
      throw ArgumentError.value(appMap, 'appMap',
          'The supplied map doesn\'t contain the mandatory key `longitude`.');
    }
    if (!appMap.containsKey('time')) {
      throw ArgumentError.value(appMap, 'appMap',
          'The supplied map doesn\'t contain the mandatory key `time`.');
    }

    // print('apppoint <- fromMap: event=${appMap["event"]}');
    var ap = CatStatus(
      timestamp: appMap['timestamp'],
      time: DateTime.parse(appMap['time']),
      latitude: appMap['latitude'],
      longitude: appMap['longitude'],
      accuracy: appMap['accuracy'] ?? -1.0,
      altitude: appMap['altitude'] ?? 0.0,
      altitude_accuracy: appMap['altitude_accuracy'] ?? -1.0,
      heading: appMap['heading'] ?? 0.0,
      heading_accuracy: appMap['heading_accuracy'] ?? -1.0,
      speed: appMap['speed'] ?? 0.0,
      speed_accuracy: appMap['speed_accuracy'] ?? -1.0,
      odometer: appMap['odometer'] ?? 0.0,
      activity_confidence: appMap['activity_confidence'] ?? 0.0,
      activity_type: appMap['activity_type'] ?? "Unknown",
      battery_level: appMap['battery_level'] ?? -1.0,
      battery_is_charging: appMap['battery_is_charging'] == 1 ? true : false,
      event: appMap['event'] ?? "",
      uploaded: appMap['uploaded'] ?? 0,
    );

    if (appMap['image_file_path'] != null && appMap['image_file_path'] != "") {
      ap.image_file_path = appMap['image_file_path'].toString();
    }
    return ap;
  }

  List<CatStatus> fromCattrackListJSON(Map<String, dynamic> json) {
    if (json == null) return [];
    List<CatStatus> cats = [];
    json.remove('');
    json.forEach((String key, dynamic value) {
      if (key.isEmpty) return;
      cats.add(CatStatus.fromCattrackJSON(value));
    });
    return cats;
  }

  factory CatStatus.fromCattrackJSON(dynamic message) {
    if (message == null) {
      return null;
    }
    final Map<String, dynamic> json = message;
    Map<String, dynamic> notes;

    if (json['notes'] != null && !(json['notes'] as String).isEmpty) {
      // print('NOTES: ${json["notes"]}');
      notes = jsonDecode(json['notes']);
    }

    // print("MESSAGE: ${message}");

    final DateTime dt = DateTime.parse(json['time']);

    dynamic getNotesValue(Map<String, dynamic> notes, String key) {
      if (notes == null || !notes.containsKey(key)) return null;
      return notes[key];
    }

    dynamic getBatteryValueFromNotes(Map<String, dynamic> notes, String key) {
      var raw = getNotesValue(notes, 'batteryStatus');
      if (raw == null) return null;
      var batteryStatus = jsonDecode(raw);
      if (batteryStatus.containsKey(key) && key == 'level')
        return batteryStatus[key].toDouble();
      if (batteryStatus.containsKey(key) && key == 'status')
        return batteryStatus[key];
      return null;
    }

    var batteryStatusString = getBatteryValueFromNotes(notes, 'status') ?? '';

    var cs = CatStatus(
      timestamp: json['timestamp'] ?? 0,
      time: dt,
      latitude: json['lat']?.toDouble() ?? 0,
      longitude: json['long']?.toDouble() ?? 0,
      accuracy: json['accuracy']?.toDouble() ?? -1,
      altitude: json['elevation']?.toDouble() ?? -1,
      altitude_accuracy: json['vAccuracy']?.toDouble() ?? -1,
      heading: json['heading']?.toDouble() ?? -1,
      heading_accuracy: json['heading_accuracy']?.toDouble() ?? -1,
      speed: json['speed']?.toDouble() ?? -1,
      speed_accuracy: json['speed_accuracy']?.toDouble() ?? -1,
      activity_type: getNotesValue(notes, 'activity').toString(),
      battery_level: getBatteryValueFromNotes(notes, 'level') ?? -1,
      battery_is_charging:
          batteryStatusString == 'full' || batteryStatusString == 'charging',
      odometer: getNotesValue(notes, 'numberOfSteps')?.toDouble(),
      // activity_confidence: location.activity.confidence,
      // battery_level: location.battery.level,

      // event: location.event,
      // uploaded: 0,
    );

    cs.imgS3 = getNotesValue(notes, 'imgS3');

    cs.uuid = json['uuid'];
    cs.name = json['name'];

    var tripStartValue = getNotesValue(notes, 'currentTripStart');
    if (tripStartValue != null && tripStartValue != '') {
      cs.tripStarted = DateTime.parse(tripStartValue);
      cs.distance = getNotesValue(notes, 'distance').toDouble();
    }

    return cs;
  }

  String activityTypeApp(String original) {
    switch (original) {
      case 'still':
      case 'Stationary':
        return 'Stationary';
      case 'on_foot':
      case 'Walking':
        return 'Walking';
      case 'walking':
        return 'Walking';
      case 'on_bicycle':
      case 'Bike':
        return 'Bike';
      case 'Running':
      case 'running':
        return 'Running';
      case 'Automotive':
      case 'in_vehicle':
        return 'Automotive';
      default:
        return 'Unknown';
    }
  }

  // toCattrackJSON creates a dynamic map for JSON (push).
  Future<Map<String, dynamic>> toCattrackJSON(
      {String uuid = "",
      String name = "",
      String version = "",
      DateTime tripStarted,
      double distance = 0}) async {
    /*
    type TrackPoint struct {
      Uuid       string    `json:"uuid"`
      PushToken  string    `json:"pushToken"`
      Version    string    `json:"version"`
      ID         int64     `json:"id"` //either bolt auto id or unixnano //think nano is better cuz can check for dupery
      Name       string    `json:"name"`
      Lat        float64   `json:"lat"`
      Lng        float64   `json:"long"`
      Accuracy   float64   `json:"accuracy"`  // horizontal, in meters
      VAccuracy  float64   `json:"vAccuracy"` // vertical, in meteres
      Elevation  float64   `json:"elevation"` //in meters
      Speed      float64   `json:"speed"`     //in kilometers per hour
      Tilt       float64   `json:"tilt"`      //degrees?
      Heading    float64   `json:"heading"`   //in degrees
      HeartRate  float64   `json:"heartrate"` // bpm
      Time       time.Time `json:"time"`
      Floor      int       `json:"floor"` // building floor if available
      Notes      string    `json:"notes"` //special events of the day
      COVerified bool      `json:"COVerified"`
      RemoteAddr string    `json:"remoteaddr"`
    }
    */
    // GOTCHA: Notes are strings.
    String notesString = "";
    String batteryStatusString = "";
    var batteryStatus = <String, dynamic>{
      'level': battery_level.toPrecision(2),
      'status': battery_is_charging
          ? (battery_level == 1 ? 'full' : 'charging')
          : 'unplugged', // full/unplugged
    };
    batteryStatusString = jsonEncode(batteryStatus);
    var notes = <String, dynamic>{
      'activity': activityTypeApp(activity_type),
      'activity_confidence': activity_confidence,
      'numberOfSteps': odometer.toInt(),
      'distance': distance,
      'batteryStatus': batteryStatusString,
      'currentTripStart': tripStarted?.toUtc()?.toIso8601String(),
    };
    if (_tripStarted != null) {
      notes['currentTripStart'] = _tripStarted.toUtc().toIso8601String();
    }
    if (image_file_path != null && image_file_path != '') {
      // Add the snap to the cat track.
      var encoded = base64Encode(File(image_file_path).readAsBytesSync());
      // print('ENCODED image as base64: ${encoded}');
      notes['imgb64'] = encoded;
    }
    // if (imgB64 != null && imgB64 != "") {
    //   notes['imgb64'] = imgB64;
    // }
    notesString = jsonEncode(notes);
    return {
      'uuid': uuid,
      'name': name,
      'version': version,
      'time': time.toUtc().toIso8601String(),
      'timestamp': timestamp,
      'lat': latitude.toPrecision(9),
      'long': longitude.toPrecision(9),
      'accuracy': accuracy.toPrecision(2),
      'speed': speed.toPrecision(2),
      'speed_accuracy': speed_accuracy.toPrecision(2),
      'heading': heading.toPrecision(0),
      'heading_accuracy': heading_accuracy.toPrecision(1),
      'elevation': altitude.toPrecision(2),
      'vAccuracy': altitude_accuracy.toPrecision(1),
      'notes': notesString,
    };
  }
}
