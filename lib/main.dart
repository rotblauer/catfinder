import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_catfinder/common/config.dart';
import 'package:flutter_catfinder/common/theme.dart';
import 'package:flutter_catfinder/resources/cat_resource.dart';
import 'package:flutter_catfinder/screens/cat_list.dart';
import 'package:flutter_catfinder/screens/map.dart';
import 'package:provider/provider.dart';
import 'package:timer_builder/timer_builder.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      statusBarColor: MyTheme.primaryColor.withOpacity(0),
      systemNavigationBarIconBrightness: Theme.of(context).brightness,
      systemNavigationBarColor: MyTheme.canvasColor,
    ));
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return // Provide the model to all widgets within the app. We're using
        // ChangeNotifierProvider because that's a simple way to rebuild
        // widgets when a model changes. We could also just use
        // Provider, but then we would have to listen to Counter ourselves.
        //
        // Read Provider's docs to learn about all the available providers.
        MultiProvider(
      // Initialize the model in the builder. That way, Provider
      // can own Counter's lifecycle, making sure to call `dispose`
      // when not needed anymore.
      providers: [
        ChangeNotifierProvider(create: (context) => CatResource()),
        ChangeNotifierProvider(create: (context) => CatSnapResource()),
      ],
      child: MaterialApp(
        routes: {
          '/': (context) => MyHomePage(),
          '/map': (context) => MapScreen(),
        },
        debugShowCheckedModeBanner: false,
        title: 'Find The Cats',
        theme: MyTheme,
        // home: MyHomePage(),
      ),
    );
  }
}

// This is a super hacky way of getting app focus updates out to the cats and snaps resources.
// It returns an empty Container widget, and its only job is to handle these
// app focus events, and to pause those resource (preventing periodic HTTP requests)
// when the app loses focus, and subsequently unpause them on regaining focus.
//
// I tried adding the WidgetBindingObserver extension to the CatResource and CatSnapResource
// classes and having them each handle these events on their own.
// Weirdly, however, only the CatResource logged print statements saying that it was
// actually getting and responding to those events. Why not CatSnapResources too?
// I tried adding the FlutterWidgetBinding.ensureInitialized() (or whatever) to above
// run(myApp()), but that didn't fix it.
//
// So that's the long story of this thing is here.
// There are probably other, more elegant workarounds (or... better redesigns entirely)
// that would resolve this kluge, but this seems to work ok for now and until
// management tells me to get lean or die trying I'm going to sit this one out.
class _MyFocusObserver extends StatefulWidget {
  const _MyFocusObserver({Key key}) : super(key: key);
  @override
  State createState() => _MyFocusObserverSt();
}

class _MyFocusObserverSt extends State<_MyFocusObserver>
    with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print("app in resumed");
        Provider.of<CatResource>(context, listen: false).unpause();
        Provider.of<CatSnapResource>(context, listen: false).unpause();
        break;
      case AppLifecycleState.inactive:
        print("app in inactive");
        Provider.of<CatResource>(context, listen: false).pause();
        Provider.of<CatSnapResource>(context, listen: false).pause();
        break;
      case AppLifecycleState.paused:
        print("app in paused");
        Provider.of<CatResource>(context, listen: false).pause();
        Provider.of<CatSnapResource>(context, listen: false).pause();
        break;
      case AppLifecycleState.detached:
        print("app in detached");
        Provider.of<CatResource>(context, listen: false).pause();
        Provider.of<CatSnapResource>(context, listen: false).pause();
        break;
    }
  }

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Find The Cats',
            style: MyTheme.textTheme.headline3,
          ),
          bottom: TabBar(tabs: [
            Tab(icon: Icon(Icons.location_history)),
            Tab(icon: Icon(Icons.photo)),
          ]),
          flexibleSpace: _MyFocusObserver(),
        ),
        body: TabBarView(children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(child: Consumer<CatResource>(builder: (_, cr, __) {
                  print('=== BUILDING CAT LIST');
                  return cr.cats.isNotEmpty
                      ? CatList(cats: cr.cats)
                      : Center(
                          child: CircularProgressIndicator(),
                        );
                })),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 0, bottom: 8, right: 16),
                      child: Consumer<CatResource>(
                        builder: (_, cr, __) {
                          var then =
                              cr.lastFetchedCats.millisecondsSinceEpoch ~/ 1000;
                          // var expected = fetchIntervalSeconds;
                          return TimerBuilder.periodic(Duration(seconds: 1),
                              builder: (context) {
                            var now =
                                DateTime.now().millisecondsSinceEpoch ~/ 1000;

                            return CircularProgressIndicator(
                                backgroundColor: cr.isPaused
                                    ? MyTheme.disabledColor
                                    : MyTheme.primaryColor,
                                value: 1 -
                                    ((now.toDouble() - then.toDouble()) /
                                        fetchIntervalSeconds.toDouble()));
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ---
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Flexible(
                    flex: 1,
                    child: Consumer<CatSnapResource>(builder: (_, cr, __) {
                      print('=== BUILDING SNAP LIST');
                      return cr.snaps.isNotEmpty
                          ? SnapList(snaps: cr.snaps)
                          : Center(
                              child: CircularProgressIndicator(),
                            );
                    })),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 0, bottom: 8, right: 16),
                      child: Consumer<CatSnapResource>(
                        builder: (_, cr, __) {
                          var then =
                              cr.lastFetchedSnaps.millisecondsSinceEpoch ~/
                                  1000;
                          // var expected = fetchIntervalSeconds;
                          return TimerBuilder.periodic(Duration(seconds: 1),
                              builder: (context) {
                            var now =
                                DateTime.now().millisecondsSinceEpoch ~/ 1000;

                            return CircularProgressIndicator(
                                backgroundColor: cr.isPaused
                                    ? MyTheme.disabledColor
                                    : MyTheme.primaryColor,
                                value: 1 -
                                    ((now.toDouble() - then.toDouble()) /
                                        fetchSnapIntervalSeconds.toDouble()));
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.miniStartDocked,
        floatingActionButton: FloatingActionButton(
          backgroundColor: MyTheme.primaryColor,
          onPressed: () {
            var p = Provider.of<CatResource>(context, listen: false);
            p.reset();
            p.fetchCats();
          },
          tooltip: 'Refresh',
          child: Icon(Icons.refresh, color: MyTheme.accentColor),
        ), // This trailing comma makes auto-formatting nicer for build methods.
      ),
    );
  }
}
