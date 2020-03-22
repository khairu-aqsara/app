import 'listen_location.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'state.dart';
import 'send_report.dart';

void main() => runApp(
    ChangeNotifierProvider(create: (context) => ReportState(), child: MyApp()));

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      title: 'COVID-19 Trace',
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: {
        '/': (context) => MyHomePage(title: 'Covid-19 Trace'),
        '/send_report': (context) => SendReport()
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  _showInfoDialog() {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('CovidTrace App'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Created by Josh Gummersall, Dudley Carr, Wes Carr'),
                InkWell(
                  child: Text(
                    'https://github.com/wescarr/covidtrace',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  onTap: () => launch("https://github.com/wescarr/covidtrace"),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: _showInfoDialog,
            )
          ],
        ),
        body: ListenLocationWidget());
  }
}
