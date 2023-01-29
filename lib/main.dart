import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'dart:convert' as convert;

import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: _PlayerVideoAndPopPage(),
    );
  }
}

class _PlayerVideoAndPopPage extends StatefulWidget {
  @override
  _PlayerVideoAndPopPageState createState() => _PlayerVideoAndPopPageState();
}

class _PlayerVideoAndPopPageState extends State<_PlayerVideoAndPopPage> {
  late VideoPlayerController _videoPlayerController;
  late VideoPlayerController _videoPlayerControllerFile;
  RxBool startedPlaying = false.obs;
  RxBool startedPlayingFile = false.obs;
  RxString state = "".obs;
  RxString stateFile = "".obs;
  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  Future<void> start() async {
    state.value = "getting link";
    stateFile.value = "getting link";
    Map<String, String> headers = <String, String>{};
    String url = "";
    var response = await http.get(Uri.parse(
        "https://api.consumet.org/anime/gogoanime/watch/spy-x-family-episode-1"));
    if (response.statusCode == 200) {
      var jsonResponse =
          convert.jsonDecode(response.body) as Map<String, dynamic>;

      jsonResponse["headers"]
          .forEach((key, value) => headers[key] = value?.toString() ?? "");
      headers["User-Agent"] = "";
      url = jsonResponse["sources"][0]["url"];
    } else {
      print('Request failed with status: ${response.statusCode}.');
    }
    // print(url);
    // print(headers);

    String m3u8 = (await http.get(Uri.parse(url))).body;

    File file = File(join((await getTemporaryDirectory()).path, "test.m3u8"));
    file.writeAsStringSync(
        getConvertFilesNameToLinks(link: url, content: m3u8));

    _videoPlayerController = VideoPlayerController.network(url,httpHeaders: headers);
    _videoPlayerControllerFile = VideoPlayerController.file(file);

    startNetworkVideo();
    startNetworkM3u8File();
  }

  startNetworkVideo() async {
    try {
      await _videoPlayerController.initialize();
      await _videoPlayerController.play();
      startedPlaying.value = true;
    } catch (e) {
      state.value = e.toString();
    }
  }

  startNetworkM3u8File() async {
    try {
      await _videoPlayerControllerFile.initialize();
      await _videoPlayerControllerFile.play();
      startedPlayingFile.value = true;
    } catch (e) {
      stateFile.value = e.toString();
    }
  }

  String getConvertFilesNameToLinks({String link = "", String content = ""}) {
    final RegExp regExpListOfLinks =
        RegExp("#EXTINF:.+?\n+(.+)", multiLine: true, caseSensitive: false);

    final RegExp netRegxUrl = RegExp(r'^(http|https):\/\/([\w.]+\/?)\S*');

    List<RegExpMatch> ListOfLinks =
        regExpListOfLinks.allMatches(content).toList();
    String baseUrl = link;
    content = content.replaceAllMapped(regExpListOfLinks, (e) {
      final bool isNetwork = netRegxUrl.hasMatch(e.group(1) ?? "");
      if (isNetwork) {
        return e.group(1)!;
      } else {
        return "${baseUrl.substring(0, baseUrl.lastIndexOf('/'))}/${e.group(1) ?? ""}";
      }
    });
    return content;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        child: Center(
          child: Column(
            children: [
              Expanded(
                child: Obx(
                  () => startedPlaying.value
                      ? AspectRatio(
                          aspectRatio: _videoPlayerController.value.aspectRatio,
                          child: VideoPlayer(_videoPlayerController),
                        )
                      : Text(state.value),
                ),
              ),
              Expanded(
                child: Obx(
                  () => startedPlayingFile.value
                      ? AspectRatio(
                          aspectRatio:
                              _videoPlayerControllerFile.value.aspectRatio,
                          child: VideoPlayer(_videoPlayerControllerFile),
                        )
                      : Text(stateFile.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
