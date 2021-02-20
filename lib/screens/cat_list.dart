import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_catfinder/common/math.dart';
import 'package:flutter_catfinder/common/pretty.dart';
import 'package:flutter_catfinder/common/theme.dart';
import 'package:flutter_catfinder/models/cat_status.dart';
import 'package:flutter_catfinder/resources/cat_resource.dart';
import 'package:flutter_catfinder/screens/map.dart';
import 'package:flutter_catfinder/secrets/config.dart' as secrets;
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:timer_builder/timer_builder.dart';

class SnapList extends StatelessWidget {
  final List<CatStatus> snaps;
  const SnapList({this.snaps});

  Widget _buildSnap(BuildContext context, CatStatus snap) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => DisplayPictureScreen(snap: snap)));
        },
        child: Container(
          child: Column(
            children: [
              Flexible(
                child: CachedNetworkImage(
                  imageUrl: secrets.S3_URL_BASE + snap.imgS3,
                  fadeInDuration: const Duration(milliseconds: 0),
                  fadeOutDuration: const Duration(milliseconds: 0),
                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                      Center(
                    child: Container(
                        height: 50,
                        width: 50,
                        child: CircularProgressIndicator(
                            value: downloadProgress.progress)),
                  ),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${snap.name}, ${prettyTimeAgo(snap.time)} ago',
                      style: Theme.of(context).textTheme.caption,
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
        crossAxisCount: 2,
        children: snaps.map((snap) => _buildSnap(context, snap)).toList());
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final CatStatus snap;

  DisplayPictureScreen({Key key, this.snap}) : super(key: key);

  MapboxMapController mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(
          child: MapboxMap(
            accessToken: secrets.MAPBOX_ACCESS_TOKEN,
            styleString: secrets.StyleStrings[secrets.StyleStrings.keys.first],
            logoViewMargins: Point(-64, -64),
            compassViewMargins: Point(24, 128),
            onMapCreated: (MapboxMapController controller) {
              print(
                  '====================== MAP CREATED ======================');
              // setState(() {
              mapController = controller;
              //   // mapController.addLayer("catTrack", "catTrack");
              // });
            },
            initialCameraPosition: CameraPosition(
                target: LatLng(snap.latitude, snap.longitude), zoom: 14),
            onStyleLoadedCallback: () {
              mapController.addCircle(CircleOptions(
                circleRadius: 10,
                circleColor: '#' +
                    MyTheme.primaryColor.value
                        .toRadixString(16)
                        .replaceFirst('ff', ''),
                geometry: LatLng(snap.latitude, snap.longitude),
              ));
            },
            trackCameraPosition: false,
          ),
        ),
        Flexible(
            flex: 2,
            child: Center(
                child: PhotoView(
              enableRotation: true,
              imageProvider: CachedNetworkImageProvider(
                secrets.S3_URL_BASE + snap.imgS3,
              ),
            ))),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${snap.name}, ${prettyTimeAgo(snap.time)} ago',
              style: MyTheme.textTheme.caption,
            ),
          ],
        ),
      ]),
    );
  }
}

class CatList extends StatelessWidget {
  final List<CatStatus> cats;
  const CatList({this.cats});

  @override
  Widget build(BuildContext context) {
    cats.sort((a, b) =>
        b.time.millisecondsSinceEpoch.compareTo(a.time.millisecondsSinceEpoch));
    return ListView(
      children: cats.map((e) {
        return CatItemState(cat: e);
      }).toList(),
    );
  }
}

class CatItemState extends StatefulWidget {
  CatStatus cat;
  CatItemState({Key key, this.cat}) : super(key: key);
  @override
  State createState() => _catItem();
}

class _catItem extends State<CatItemState> {
  CatStatus _cat;
  bool _showingCatDetails = false;

  @override
  void initState() {
    super.initState();
    _cat = widget.cat;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var mycat = context.select<CatResource, CatStatus>(
        // Here, we are only interested whether [item] is inside the cart.
        (cr) => cr.cats.firstWhere((element) {
              return element.uuid == _cat.uuid;
            }, orElse: () => null));

    if (mycat != null) {
      setState(() {
        _cat = mycat;
      });
    }

    print('=== BUILDING CAT: ${_cat.name}');
    final Widget _name =
        Text('${_cat.name}'); // , style: Theme.of(context).textTheme.bodyText1

    final Widget _tripStats = Row(
      children: [
        (_cat.tripStarted == null)
            ? null
            : Text(
                '${prettyDistance(_cat.distance)}, ${_cat.odometer ~/ 1} steps since ${prettyTimeAgo(_cat.tripStarted).replaceAll(' ', '')} ago')
      ],
    );

    final Widget _speed = Text('${prettySpeed(_cat.speed)}');
    final Widget _accuracy = Text("± ${_cat.accuracy.toPrecision(1)}m");
    final Widget _altitude = Text('⛰ ${_cat.altitude.toPrecision(1)}m');
    Row _location = Row(
      children: [
        Padding(padding: EdgeInsets.only(right: 4), child: _altitude),
        Padding(padding: EdgeInsets.only(right: 4), child: _accuracy),
      ],
    );
    if (_cat.speed > 0)
      _location.children.insert(
          0, Padding(padding: EdgeInsets.only(right: 4), child: _speed));

    final Widget catMovement = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tripStats,
        _location,
      ],
    );

    return Column(
      children: [
        Card(
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MapScreen(cat: _cat)));
                },
                onLongPress: () {
                  setState(() {
                    _showingCatDetails = !_showingCatDetails;
                  });
                },
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      isThreeLine: true,
                      leading: prettyActivityIcon(_cat.activity_type),
                      title: _name,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          new TimerBuilder.periodic(Duration(seconds: 1),
                              builder: (context) {
                            return Text(prettyTimeAgo(_cat.time));
                          }),
                          Container(
                            height: 12,
                            width: 12,
                            margin: EdgeInsets.all(6),
                            child: CircularProgressIndicator(
                              backgroundColor: _cat.battery_is_charging
                                  ? Colors.lightGreen.withAlpha(100)
                                  : Colors.redAccent.withAlpha(100),
                              value: _cat.battery_level,
                              strokeWidth: 2,
                            ),
                          ),
                        ],
                      ),
                      subtitle: catMovement,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Visibility(
          visible: _showingCatDetails,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text('${_cat.uuid}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
