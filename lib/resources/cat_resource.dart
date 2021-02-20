import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_catfinder/common/config.dart';
import 'package:flutter_catfinder/models/cat_status.dart';
import 'package:flutter_catfinder/secrets/config.dart' as secrets;
import 'package:http/http.dart' as http;
import 'package:mapbox_gl/mapbox_gl.dart';

class CatSnapResource with ChangeNotifier {
  final Duration fetchIntervalDuration;
  final Duration resourceStartLimit;
  CatSnapResource({
    this.fetchIntervalDuration =
        const Duration(seconds: fetchSnapIntervalSeconds),
    this.resourceStartLimit = const Duration(days: 30),
  }) {
    fetchSnaps();
    fetchPeriodically();
  }

  reset() {
    _snaps = [];
    notifyListeners();
  }

  bool isPaused = false;
  pause() {
    isPaused = true;
    notifyListeners();
  }

  unpause() {
    isPaused = false;
    notifyListeners();
    if (DateTime.now().difference(lastFetchedSnaps) >
        this.fetchIntervalDuration) {
      this.fetchSnaps();
    }
  }

  List<CatStatus> _snaps = [];
  List<CatStatus> get snaps {
    return _snaps;
  }

  DateTime lastFetchedSnaps = DateTime.fromMillisecondsSinceEpoch(0);

  fetchPeriodically() async =>
      Timer.periodic(this.fetchIntervalDuration, (timer) {
        if (!isPaused) this.fetchSnaps();
      });

  Future<List<CatStatus>> fetchSnaps() async {
    print('=== FETCHING CATS ${DateTime.now().toLocal()}');

    var tstart = lastFetchedSnaps.millisecondsSinceEpoch == 0
        ? DateTime.now().subtract(this.resourceStartLimit)
        : lastFetchedSnaps;

    lastFetchedSnaps = DateTime.now();

    var params = {"tstart": (tstart.millisecondsSinceEpoch ~/ 1000).toString()};

    final response =
        await http.get(Uri.https(secrets.API_URL, 'catsnaps', params));

    if (response.statusCode == 200) {
      print('==> OK: ${response.body}');
      List<dynamic> res = jsonDecode(response.body);

      if (tstart.millisecondsSinceEpoch == 0) {
        _snaps = res
            ?.map((e) => CatStatus.fromCattrackJSON(e))
            ?.toList(growable: false)
            ?.reversed
            ?.toList(growable: false);
      } else {
        // Any new (updated in period) snaps need to
        // inserted at the front of the list.
        var newsnaps = res
            ?.map((e) => CatStatus.fromCattrackJSON(e))
            ?.toList(growable: false)
            ?.reversed
            ?.toList(growable: false);
        _snaps = [...?newsnaps, ...?_snaps];
      }

      notifyListeners();
    } else {
      lastFetchedSnaps = DateTime.fromMillisecondsSinceEpoch(0);

      print('==> ERROR fetchCats: ${response}');
      throw Exception('Failed to load cats.');
    }
  }
}

class CatResource with ChangeNotifier {
  final Duration fetchIntervalDuration;
  final Duration resourceStartLimit;
  CatResource({
    this.fetchIntervalDuration = const Duration(seconds: fetchIntervalSeconds),
    this.resourceStartLimit = const Duration(days: 3),
  }) {
    fetchCats();
    fetchPeriodically();
  }

  reset() {
    _cats = [];
    notifyListeners();
  }

  List<CatStatus> _cats = [];
  List<CatStatus> get cats {
    return _cats;
  }

  bool isPaused = false;
  pause() {
    isPaused = true;
    notifyListeners();
  }

  unpause() {
    isPaused = false;
    notifyListeners();
    if (DateTime.now().difference(lastFetchedCats) >
        this.fetchIntervalDuration) {
      this.fetchCats();
    }
  }

  DateTime lastFetchedCats = DateTime.fromMillisecondsSinceEpoch(0);
  fetchPeriodically() => Timer.periodic(this.fetchIntervalDuration, (timer) {
        if (!isPaused) this.fetchCats();
      });

  Future<List<CatStatus>> fetchCats() async {
    print('=== FETCHING CATS ${DateTime.now().toLocal()}');

    final response = await http.get(Uri.https(secrets.API_URL, 'lastknown'));

    if (response.statusCode == 200) {
      print('==> OK');

      lastFetchedCats = DateTime.now();

      _cats = CatStatus()
          .fromCattrackListJSON(jsonDecode(response.body))
          .where((cat) => cat.time
              .isAfter(DateTime.now().subtract(this.resourceStartLimit)))
          .toList();

      notifyListeners();
    } else {
      print('==> ERROR#fetchCats: ${response}');
      throw Exception('Failed to load cats.');
    }
  }
}

class CatLines {
  final String raw;

  CatLines({this.raw});

  List<CatLine> lines;

  parse() {
    Map<String, dynamic> featureCollection = jsonDecode(this.raw);
    List<dynamic> features = featureCollection['features'];
  }
}

class CatLine {
  String rawFeatures;

  CatLine({this.rawFeatures});

  List<LatLng> latlngs;
  DateTime start;
  DateTime end;
  LatLngBounds boundingBox;

  initParse() {}
}
