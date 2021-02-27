import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_test/audio.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: AudioServiceWidget(
          child: MyHomePage(title: 'Flutter Demo Home Page'),
        ),
    );
  }
}

/// Home Page
class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  Future<void> _onStart() async {
    Map<String, dynamic> info = {
      'episodeTitle': 'MEUFF-E04 - Détection des jeunes, Division 2 et expériences personnelles',
      'episodeDuration': 3636, 
      'showId': '5f2423e8626cef529c2ac6b9',
      'episodeThumbnail': 'https://i1.sndcdn.com/artworks-Kk1AUF7jnwaqa3cS-VJFflg-t3000x3000.jpg',
      'showTitle': 'Passement de Jambes',
      'episodeUrl': 'https://feeds.soundcloud.com/stream/992688748-p2j_fr-meuff-e04-detection-d2.mp3',
      'showThumbnail': 'https://i1.sndcdn.com/avatars-000379649033-tkqgdf-original.jpg',
      'episodeId': '603773ddaf6f687d91268253',
      'userId': '5f2423e8626cef529c2ac6b8',
      'username': null
    };

    try {

      print('IN START');

      if (!AudioService.connected)
        await AudioService.connect();

      await AudioService.start(backgroundTaskEntrypoint: backgroundTaskEntrypoint, params: info);
    } catch (error) {
      print('start error');
      print(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Time'),
            StreamBuilder(
              stream: AudioService.positionStream,
              builder: (BuildContext context, AsyncSnapshot<Duration> snapshot) {
                print('Snapshot data: ${snapshot?.data}');
                return Text('${!snapshot.hasData ? 0 : snapshot.data.inSeconds}');
              }
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_left),
                  onPressed: () => AudioService.seekTo(Duration(seconds: AudioService.playbackState.position.inSeconds - 15 < 0 ? 0 : AudioService.playbackState.position.inSeconds - 15)),
                ),
                StreamBuilder(
                  stream: AudioService.playbackStateStream,
                  builder: (BuildContext context, AsyncSnapshot<PlaybackState> snapshot) {
                    return IconButton(
                      color: Colors.red,
                      icon: Icon(
                        snapshot?.data?.playing ?? false ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: () async {
                        if (!AudioService.connected || AudioService.currentMediaItem == null) return _onStart();
                        if (snapshot.hasData && !snapshot.data.playing) return AudioService.play();
                        if (snapshot.hasData && snapshot.data.playing) return AudioService.pause();
                      }
                    );
                  }
                ),
                IconButton(
                  icon: Icon(Icons.arrow_right),
                  onPressed: () => AudioService.seekTo(Duration(seconds: AudioService.playbackState.position.inSeconds + 15)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}