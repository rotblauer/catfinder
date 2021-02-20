import 'package:flutter/material.dart';
import 'package:flutter_catfinder/common/math.dart';

String secondsToPrettyDuration(double seconds, [bool abbrev]) {
  int secondsRound = seconds ~/ 1;
  int days = secondsRound ~/ (24 * 60 * 60);
  secondsRound = secondsRound % (24 * 60 * 60);
  int hours = secondsRound ~/ 3600;
  secondsRound = secondsRound % 3600;
  int minutes = secondsRound ~/ 60;
  secondsRound = secondsRound % 60;
  String out = "";
  days > 0 ? out += days.toString() + 'd ' : null;
  if (abbrev != null && days >= 1 && abbrev) return out.trim();
  hours > 0 ? out += hours.toString() + 'h ' : null;
  if (abbrev != null && hours > 6 && abbrev) return out.trim();
  minutes > 0 ? out += minutes.toString() + 'm ' : null;
  if (abbrev != null && (hours >= 1 || minutes >= 10) && abbrev)
    return out.trim();
  out += secondsRound.toString() + 's';
  return out;
}

String prettyTimeAgo(DateTime then) {
  if (then == null) return 'for..ev..er...';
  return '${secondsToPrettyDuration(DateTime.now().difference(then).inSeconds.toDouble(), true)}';
}

String prettySpeed(double speed) {
  if (speed <= 0) return '0km/h';
  return '${(speed * 3.6).toPrecision(1)}km/h';
}

const Map<String, Color> activityColors = {
  'Stationary': Colors.deepOrange,
  'still': Colors.deepOrange,
  //
  'Walking': Colors.amber,
  'on_foot': Colors.amber,
  'walking': Colors.amber,
  //
  'Running': Colors.green,
  'running': Colors.green,
  //
  'Bike': Colors.lightBlue,
  'on_bicycle': Colors.lightBlue,
  //
  'Automotive': Colors.purple,
  'in_vehicle': Colors.purple,
};

Color getActivityColor(String activityType) {
  if (activityColors.containsKey(activityType))
    return activityColors[activityType];
  return Colors.grey;
}

Icon prettyActivityIcon(String activity, {double size}) {
  switch (activity) {
    case 'Stationary':
    case 'still':
      return Icon(
        Icons.weekend,
        size: size,
        // color: Theme.of(context).primaryColor,
        color: getActivityColor(activity),
        // color: Theme.of(context).accentColor,
      );
    case 'Walking':
    case 'walking':
    case 'on_foot':
      return Icon(
        Icons.directions_walk,
        size: size,
        color: getActivityColor(activity),
      );
    case 'Bike':
    case 'on_bicycle':
      return Icon(
        Icons.directions_bike,
        size: size,
        color: getActivityColor(activity),
      );
    case 'Running':
    case 'running':
      return Icon(
        Icons.directions_run,
        size: size,
        color: getActivityColor(activity),
      );
    case 'Automotive':
    case 'in_vehicle':
      return Icon(
        Icons.directions_car,
        size: size,
        // color: Theme.of(context).primaryColor,
        color: getActivityColor(activity),
      );
    default:
      return Icon(
        Icons.device_unknown,
        size: size,
        color: getActivityColor(activity),
      );
  }
}

String prettyDistance(double meters) {
  if (meters > 1000) {
    return '${(meters / 1000).toPrecision(1)}km';
  }
  return '${meters ~/ 1}m';
}
