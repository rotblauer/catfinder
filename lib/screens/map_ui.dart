import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_catfinder/common/pretty.dart';
import 'package:flutter_catfinder/common/theme.dart';
import 'package:flutter_catfinder/models/cat_status.dart';
import 'package:flutter_catfinder/resources/cat_resource.dart';
import 'package:flutter_catfinder/secrets/config.dart' as secrets;
import 'package:http/http.dart' as http;
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:provider/provider.dart';

class MapUiBody extends StatefulWidget {
  final CatStatus cat;
  const MapUiBody({Key key, this.cat}) : super(key: key);

  @override
  State createState() => FullMapState();
}

final double _defaultZoom = 14;

String globalMapStyle;

class FullMapState extends State<MapUiBody> {
  MapboxMapController mapController;
  CatStatus cat;

  // This is a one-off incrementer (maxes at 1) that is used to
  // differentiate the first map state loading vs subsequent updates.
  // This helps determine if
  // - Should we fit the map to linestring bounds (if any?); only want to do
  //   this on the first load.
  // - Should we put the map on the cat with animation or not (with animation
  //   only for subsequent calls).
  int _drawCount = 0;

  // _ending is called by dispose and prevents the map controller-dependent drawing
  // functions from calling a disposed value. This seems hacky.
  bool _ending = false;

  // _isLoaded is set to true by the MapBoxMap onMapLoaded callback.
  // This is needed because of an UNDOCUMENTED GOTCHA: if you try to
  // add circles to the map before the map is LOADED (NOT CREATED),
  // it will cause a 'method called on null value' exception.
  // So we have to wait until the map is LOADED before drawing the geometries.
  bool _isLoaded = false;

  // _followCatLocation is a mode where the map centers on the cat
  // when it receives updates about the cat.
  bool _followCatLocation = false;

  String _styleString = globalMapStyle ?? secrets.StyleStrings.keys.first;

  int linestringsLastFetched;

  void _onStyleLoaded() {
    print('====================== STYLE LOADED ======================');
    setState(() {
      _isLoaded = true;
    });
  }

  @override
  void initState() {
    print('=========================== INIT STATE ======================');
    super.initState();

    // Assign the state's initial cat from the inherited cat.
    cat = widget.cat;
  }

  @override
  void dispose() {
    _ending = true;
    mapController?.dispose();
    super.dispose();
  }

  void _onDraw() {
    if (_drawCount > 0) return;
    setState(() {
      _drawCount++;
    });
  }

  // _drawCatLocationCircle puts a circle on the map where the cat is.
  Future<Circle> _drawCatLocationCircle() async {
    return mapController.addCircle(CircleOptions(
      circleRadius: 10,
      circleColor: '#' +
          MyTheme.primaryColor.value.toRadixString(16).replaceFirst('ff', ''),
      geometry: LatLng(cat.latitude, cat.longitude),
    ));
  }

  // _drawCatAccuracyCircle puts a circle on the map scaled to the cat's
  // reported accuracy.
  Future<Circle> _drawCatAccuracyCircle() async {
    var metersPerPixel =
        await mapController.getMetersPerPixelAtLatitude(cat.latitude);

    return mapController.addCircle(CircleOptions(
        circleRadius: cat.accuracy / metersPerPixel,
        circleOpacity: 0.3,
        circleColor: '#' +
            MyTheme.buttonColor.value.toRadixString(16).replaceFirst('ff', ''),
        geometry: LatLng(cat.latitude, cat.longitude)));
  }

  void _drawCatCircles() async {
    // Put accuracy circle down first.
    // This keeps the semi-transparent color from changing the appearance
    // of our carefully considered cat theme.
    // The drawback is that for certain zooms and accuracies, the
    // accuracy circle may be hidden behind the location circle.
    await _drawCatAccuracyCircle();
    _drawCatLocationCircle();
  }

  // _mapOnCat moves the cat to the middle of the map.
  Future<bool> _mapOnCat({bool defaultZoom: false, bool fly: false}) async {
    // Put the map on the cat.
    double zoom = mapController.cameraPosition?.zoom ?? _defaultZoom;
    if (defaultZoom) zoom = _defaultZoom;
    if (fly) {
      return mapController.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(cat.latitude, cat.longitude), zoom));
    } else {
      return mapController.moveCamera(CameraUpdate.newLatLngZoom(
          LatLng(cat.latitude, cat.longitude), zoom));
    }
  }

  // _moveMapToBounds animates a camera move to fit bounds, eg. linestring bounds.
  Future<bool> _moveMapToBounds(LatLngBounds bounds) async {
    if (bounds == null) return false;
    return mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds));
  }

  // _getAndDrawLines fetches cat linestrings via http and
  // puts them on the map.
  // It REMOVES any existing lines on the map IFF the fetch and parse was
  // successful. Removing lines "on demand" like this reduces flicker.
  Future<LatLngBounds> _getAndDrawLines() async {
    // Set this up first so we don't leave any temporal gaps.
    int start = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    Map<String, dynamic> params = {
      'cats': cat.uuid,
      'tstart': (linestringsLastFetched ??
              cat.tripStarted.millisecondsSinceEpoch ~/ 1000)
          .toString(),
      'tend': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'nosynthetic': 'true',
    };

    final response =
        await http.get(Uri.https(secrets.API_URL_ENGINE, 'linestring', params));
    if (response.statusCode == 200) {
      // Cache the last linestring fetch timestamp.
      // This enables lean payloads and eliminates unnecessary line redraws.
      /*
      TODO
      
      This could be optimized further by storing the linestrings
      in the lifted state so that they only every need to be fetched once
      (instead of being fetched on each MapBodyUI widget build).
      */
      linestringsLastFetched = start;

      Map<String, dynamic> featureCollection = jsonDecode(response.body);
      List<dynamic> features = featureCollection['features'];

      if (features.length == 0) {
        print('WARN linestring empty; returning early');
        return null;
      }

      // Since (above) we cache and reuse the last fetch timestamp,
      // we don't need to clear the lines.
      // mapController.clearLines();

      double southwest_lat;
      double southwest_lng;
      double northeast_lat;
      double northeast_lng;

      features.forEach((feature) async {
        Map<dynamic, dynamic> feat = feature;
        // print('INFO linestring adding type=${feat['geometry']['type']}');
        List<dynamic> rawlatlngs = feat['geometry']['coordinates'];
        List<LatLng> latlngs = rawlatlngs.map((e) {
          final List<dynamic> ll = e;
          final lll = LatLng(ll[1].toDouble(), ll[0].toDouble());

          if (southwest_lat == null || lll.latitude.abs() < southwest_lat.abs())
            southwest_lat = lll.latitude;
          if (southwest_lng == null ||
              lll.longitude.abs() < southwest_lng.abs())
            southwest_lng = lll.longitude;
          if (northeast_lat == null || lll.latitude.abs() > northeast_lat.abs())
            northeast_lat = lll.latitude;
          if (northeast_lng == null ||
              lll.longitude.abs() > northeast_lng.abs())
            northeast_lng = lll.longitude;

          return lll;
        }).toList();
        await mapController.addLine(LineOptions(
            lineColor: '#' +
                getActivityColor(feat['properties']['Activity'])
                    .value
                    .toRadixString(16)
                    .replaceFirst('ff', ''),
            lineWidth: 2,
            geometry: latlngs));
      });

      var southwest = LatLng(southwest_lat * 0.99999, southwest_lng * 0.99999);
      var northeast = LatLng(northeast_lat * 1.00001, northeast_lng * 1.00001);

      return LatLngBounds(southwest: southwest, northeast: northeast);
    } else {
      print('ERROR fetch linestrings: $response');
    }
    return null;
  }

  void _main({bool isInit, bool moveToCat, bool drawGeometries: true}) async {
    print("=== MapBox Drawings MAIN");

    LatLngBounds bounds;

    if (drawGeometries) {
      // Since this can be called multiple times we need to clear the existing drawn circles.
      mapController.clearCircles();
      // ... and redraw them in case they changed.
      _drawCatCircles();

      bounds = await _getAndDrawLines();
    }

    // Only fit the map to line bounds on the first drawing.
    if (isInit) {
      // HTTP request the lines and put them on the map.
      if (!await _moveMapToBounds(bounds)) {
        // If _moveMapToBounds has returned false it's _probably_ because there were no
        // linestrings for the stationary cat (thus no bounds).
        // So jut put the map on the cat.
        await _mapOnCat(defaultZoom: !moveToCat);
      }

      // Else this is not the first drawing.
    } else if (moveToCat) {
      await _mapOnCat(fly: true);
    }
    // Increment the draw counter, effectively only signaling that 'init' is done.
    _onDraw();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        (mapController == null || _ending || !_isLoaded)
            ? Container()
            : Consumer<CatResource>(
                builder: (_, cr, __) {
                  print('___ CAT CONTAINER RESOURCE CALL __');
                  // -----------------------------------------------------------
                  final bool isInit = _drawCount == 0;

                  final newcat =
                      cr.cats.firstWhere((element) => element.uuid == cat.uuid);

                  final drawGeometries =
                      isInit || (newcat.time.isAfter(cat.time));

                  cat = newcat;

                  _main(
                    isInit: isInit,
                    moveToCat: _followCatLocation,
                    drawGeometries: drawGeometries,
                  );
                  // -----------------------------------------------------------
                  return Container();
                },
              ),
        MapboxMap(
          accessToken: secrets.MAPBOX_ACCESS_TOKEN,
          styleString: secrets.StyleStrings[_styleString],
          onMapCreated: (MapboxMapController controller) {
            print('====================== MAP CREATED ======================');
            setState(() {
              mapController = controller;
              // mapController.addLayer("catTrack", "catTrack");
            });
          },
          initialCameraPosition: CameraPosition(
              target: LatLng(widget.cat.latitude, widget.cat.longitude),
              zoom: _defaultZoom),
          onStyleLoadedCallback: _onStyleLoaded,
          trackCameraPosition: true,
          onMapLongClick: (Point<double> p, LatLng ll) {
            print('=== MAP LONG CLICK');
            setState(() {
              _followCatLocation = !_followCatLocation;
            });
          },
          compassViewMargins: Point(24, 128),
          logoViewMargins: Point(-64, -64),
        ),
        Container(
          margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Padding(
              padding: EdgeInsets.all(8),
              child: DropdownButton<String>(
                isDense: true,
                value: _styleString,
                icon: Icon(Icons.arrow_downward),
                iconSize: 24,
                elevation: 16,
                style: TextStyle(
                  color: MyTheme.primaryColor,
                ),
                underline: Container(
                  height: 2,
                  color: MyTheme.primaryColor,
                ),
                onChanged: (String newValue) {
                  globalMapStyle = newValue;
                  setState(() {
                    _styleString = newValue;
                    mapController.addLayer("catTrack", "catTrack");
                  });
                },
                // items: <String>['One', 'Two', 'Free', 'Four']
                items: secrets.StyleStrings.keys
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              )),
        ),
        Visibility(
            visible: _followCatLocation,
            child: Center(
                child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.location_searching,
                      color: MyTheme.primaryColor.withOpacity(0.62),
                      size: 48,
                    )))),
      ],
    );
  }
}
