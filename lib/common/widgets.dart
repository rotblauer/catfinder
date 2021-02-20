// import 'package:flutter/material.dart';

// class TimeAgo extends StatefulWidget {
//   final DateTime relativeTime;
//   final int periodSeconds;
//   const TimeAgo({Key key, @required this.relativeTime, this.periodSeconds = 1})
//       : super(key: key);

//   @override
//   State createState() => _TimeAgoState();
// }

// class _TimeAgoState extends State<TimeAgo> {
//   Timer _intervalFn;

//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     _intervalFn = timer.periodic(new Duration(seconds: 1), (timer) {
//       setState(() {
//         _catTimeAgo = prettyTimeAgo(_cat.time);
//       });
//     });
//   }
//   @override
//   Widget build(BuildContext context) {}
// }
