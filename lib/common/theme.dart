import 'package:flutter/material.dart';

final ThemeData MyTheme = ThemeData(
    // This is the theme of your application.
    //
    // Try running your application with "flutter run". You'll see the
    // application has a blue toolbar. Then, without quitting the app, try
    // changing the primarySwatch below to Colors.green and then invoke
    // "hot reload" (press "r" in the console where you ran "flutter run",
    // or simply save your changes to "hot reload" in a Flutter IDE).
    // Notice that the counter didn't reset back to zero; the application
    // is not restarted.
    primaryColor: Colors.deepOrange.withBlue(90),
    brightness: Brightness.dark,
    textTheme: TextTheme(
      headline1: TextStyle(color: Colors.tealAccent),
      headline2: TextStyle(color: Colors.tealAccent),
      headline3: TextStyle(color: Colors.tealAccent),
      headline4: TextStyle(color: Colors.tealAccent),
      headline5: TextStyle(color: Colors.tealAccent),
      headline6: TextStyle(color: Colors.tealAccent),
    )
    // primaryColor: Colors.deepPurple[700].withRed(50),
    );
