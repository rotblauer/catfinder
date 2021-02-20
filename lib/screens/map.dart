import 'package:flutter/material.dart';
import 'package:flutter_catfinder/common/config.dart';
import 'package:flutter_catfinder/common/pretty.dart';
import 'package:flutter_catfinder/common/theme.dart';
import 'package:flutter_catfinder/models/cat_status.dart';
import 'package:flutter_catfinder/resources/cat_resource.dart';
import 'package:flutter_catfinder/screens/map_ui.dart';
import 'package:provider/provider.dart';
import 'package:timer_builder/timer_builder.dart';

class _MapScreenOverlay extends StatelessWidget {
  CatStatus cat;
  _MapScreenOverlay({this.cat});
  @override
  Widget build(BuildContext context) {
    var catName = Text('${cat.name}',
        style: Theme.of(context).textTheme.apply(fontSizeDelta: 3).bodyText1);

    var catTime = TimerBuilder.periodic(Duration(seconds: 1),
        builder: (context) => Text('reported ${prettyTimeAgo(cat.time)} ago'));

    var catSince = TimerBuilder.periodic(Duration(minutes: 5),
        builder: (context) => Text(
            'since ${prettyTimeAgo(cat.tripStarted)} ago',
            style: Theme.of(context)
                .textTheme
                .apply(bodyColor: Theme.of(context).disabledColor)
                .bodyText1));

    var catTrip = Text(
        '${prettyDistance(cat.distance)}, ${cat.odometer ~/ 1} steps',
        style: Theme.of(context)
            .textTheme
            .apply(
                bodyColor: Theme.of(context).primaryColor,
                displayColor: Theme.of(context).primaryColor)
            .bodyText1);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Row(children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: prettyActivityIcon(cat.activity_type),
            )
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flexible(child: child),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                // crossAxisAlignment: CrossAxisAlignment.end,
                children: [catName, Container(width: 12), catTime]),
            Row(children: [
              catTrip,
              Container(
                width: 8,
              ),
              catSince
            ])
          ],
        )
      ]),
    );
  }
}

class MapScreen extends StatelessWidget {
  final CatStatus cat;
  const MapScreen({Key key, this.cat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MapManager(),
          MapUiBody(cat: cat),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).canvasColor,
                          boxShadow: [
                            BoxShadow(
                                blurRadius: 2,
                                spreadRadius: 1,
                                offset: Offset.fromDirection(90))
                          ],
                          borderRadius:
                              BorderRadius.only(topRight: Radius.circular(16))),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Consumer<CatResource>(
                            builder: (context, catLocation, child) {
                          return _MapScreenOverlay(
                              cat: catLocation.cats.firstWhere(
                                  (element) => element.uuid == cat.uuid));
                        }),
                      )),
                  Padding(
                      padding: EdgeInsets.only(top: 0, bottom: 8, right: 16),
                      child: Consumer<CatResource>(
                        builder: (_, cr, __) {
                          var then =
                              cr.lastFetchedCats.millisecondsSinceEpoch ~/ 1000;
                          return TimerBuilder.periodic(Duration(seconds: 1),
                              builder: (context) {
                            var now =
                                DateTime.now().millisecondsSinceEpoch ~/ 1000;
                            return CircularProgressIndicator(
                                backgroundColor: MyTheme.primaryColor,
                                value: 1 -
                                    ((now.toDouble() - then.toDouble()) /
                                        fetchIntervalSeconds.toDouble()));
                          });
                        },
                      )),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
