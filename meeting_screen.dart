import 'dart:convert';
import 'dart:developer';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_uikit/agora_uikit.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:greymatter/AllScreens/PsychologistPanel/Screens/Home/PSuccessfulSessionScreen.dart';
import 'package:greymatter/Apis/DoctorApis/availability_api.dart';
import 'package:greymatter/Apis/meeting_api/get_token_api.dart';
import 'package:greymatter/agora/chat_config.dart';
import 'package:greymatter/constants/globals.dart';
import 'package:greymatter/model/UModels/user_psychologist_model.dart';
import 'package:greymatter/widgets/loadingWidget.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../AllScreens/UserPanel/UScreens/UBookingScreens/USessionSucessfulScreen.dart';
import '../widgets/app_bar/app_bar.dart';

/*const appId = "<-- Insert App Id -->";
const token = "<-- Insert Token -->";
const channel = "<-- Insert Channel Name -->";*/

class MeetingScreen extends StatefulWidget {
  final String bookingId;
  final UPsychologistModel? model;
  final String date;
  final String issue;
  const MeetingScreen(
      {Key? key,
      required this.bookingId,
      required this.model,
      required this.date,
      required this.issue})
      : super(key: key);

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  int uid = 0;

  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isJoined = false;

  @override
  void initState() {
    //initAgora();
    _getPrefs();
    _getMeetingToken();
    //setUpAgora();

    super.initState();
  }

  _getPrefs() async {
    var prefs = await SharedPreferences.getInstance();
    _isUser = prefs.getBool(Keys().isUser) ?? false;
    if (_isUser) {
      role = 1;
    } else {
      role = 2;
    }
    log("is user $_isUser");
  }

  bool _isLoading = false;
  bool _isUser = false;

/*  Future<void> initAgora() async {
    _isLoading = true;
    // retrieve permissions
    await [Permission.microphone, Permission.camera].request();

    var prefs = await SharedPreferences.getInstance();
   _isUser =  prefs.getBool(Keys().isUser) ?? false;
    //create the engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: AgoraChatConfig.appKey,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            log("local user ${connection.localUid} joined");
            setState(() {
              _localUserJoined = true;
              uid = connection.localUid!;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            log("remote user $remoteUid joined");
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            log("remote user $remoteUid left channel");
            setState(() {
              _remoteUid = null;
            });
          },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            log(
                '[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            log("user ${connection.localUid} left");
          }),
    );

    await _engine.setClientRole(role: _isUser? ClientRoleType.clientRoleAudience : ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.startPreview();

    ChannelMediaOptions options = ChannelMediaOptions(
      clientRoleType:_isUser? ClientRoleType.clientRoleAudience : ClientRoleType.clientRoleBroadcaster,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    );


    await _engine.joinChannel(
      token: AgoraChatConfig.agoraToken,
      channelId: AgoraChatConfig.userId,
      uid: _isUser? _remoteUid! :uid,
      options: options,
    );
    setState(() {
      _isLoading = false;
    });
  }*/

  @override
  void dispose() async {
    //_engine.leaveChannel();
    //_engine.release();
    await _client.engine.disableAudio();
    await _client.engine.disableVideo();
    await _client.engine.leaveChannel();
    await _client.release();
    super.dispose();
  }

  //static int _uId = 0;

  //agora_token
  //channel_name

  int role = 1;
  String channelName = '';
  String rtcToken = '';
  //int uid = 0;
  _getMeetingToken() {
    log(widget.bookingId.toString());
    _isLoading = true;
    final resp = GetMeetingTokenApi().get(bookingId: widget.bookingId);
    resp.then((value) {
      log(value.toString());
      if (value['status'] == true) {
        rtcToken = value['agora_token'];
        channelName = value['channel_name'];
        uid = int.parse(value['uid']);
        log(rtcToken);
        log(channelName);
        log(uid.toString());
        //fetchToken(uid, channelName, role);
        setUpAgora();
      } else {
        Fluttertoast.showToast(msg: value['error']);
        setState(() {
          //_isLoading = false;
        });
      }
    });
  }

  Future<void> fetchToken(int uid, String channelName, int tokenRole) async {
    var prefs = await SharedPreferences.getInstance();
    var v = prefs.getString(Keys().cookie);
    var headers = {
      'Content-Type': 'application/json',
      'Cookie': 'PHPSESSID=$v'
    };
    log(channelName.toString());
    String url =
        //'$tokenUrl/rtc/$channelName/${tokenRole.toString()}/uid/${uid.toString()}';
        // '$tokenUrl?channelName=$channelName&uid=$uid&role=$tokenRole&tokenExpire=3600';
        '$tokenUrl?channelName=$channelName&uid=${uid.toString()}&role=${tokenRole.toString()}&tokenExpire=3600';
    var request = http.Request('PUT', Uri.parse(url));
    request.body = json.encode({"booking_id": widget.bookingId});
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    var resp = jsonDecode(await response.stream.bytesToString());
    if (response.statusCode == 200) {
      // If the server returns an OK response, then parse the JSON.
      Map<String, dynamic> json = resp;
      log("message $json");
      String newToken = json['token'];
      //log('Token Received: $newToken');
      // Use the token to join a channel or renew an expiring token
      setState(() {
        rtcToken = newToken;
      });
      //setUpAgora();
    } else {
      // If the server did not return an OK response,
      // then throw an exception.
      throw Exception(
          'Failed to fetch a token. Make sure that your server URL is valid');
    }

    // Prepare the Url

    // Send the request
    //  final response = await http.get(Uri.parse(url));
  }

  String tokenUrl =
      'https://theataraxis.com/ataraxis/api-user/agora/token-genrate.php';
  // "https://agora-token-service-production-e641.up.railway.app";
  //"https://theataraxis.com/ataraxis/api-user/generate-agora-token.php";

  setUpAgora() async {
    log(role.toString());
    log(channelName.toString());
    log(uid.toString());
    //_isLoading = true;
    _client = AgoraClient(
      enabledPermission: [
        Permission.camera,
        Permission.microphone,
      ],
      agoraConnectionData: AgoraConnectionData(
          appId: AgoraChatConfig.appKey,
          channelName: channelName,
          //tempToken: rtcToken,
          tokenUrl: tokenUrl),
      agoraEventHandlers: AgoraRtcEventHandlers(
        onConnectionLost: (connection) {
          // Fluttertoast.showToast(msg: "${connection.localUid} lost connection");
        },
        onJoinChannelSuccess: (connection, id) {
          //Fluttertoast.showToast(msg: "${connection.localUid} joined");
        },
        onUserJoined: (connection, id, elapsed) {
          // Fluttertoast.showToast(msg: "${connection.localUid} user joined");
        },
        onLeaveChannel: (connection, status) async {
          //Fluttertoast.showToast(msg: "${connection.localUid} user left");
        },
        onError: (code, err) {
          Fluttertoast.showToast(msg: code.name);
        },
        onRequestToken: (connection) {
          // _client.engine.renewToken(rtcToken);
          // _client.engine.joinChannel(
          //     token: rtcToken,
          //     channelId: channelName,
          //     uid: uid,
          //     options: ChannelMediaOptions());
        },
        onTokenPrivilegeWillExpire: (connection, str) async {
          log(str);
          log(connection.localUid.toString());
          log(connection.channelId.toString());
          // await fetchToken(uid, channelName, role);
          // final resp =
          //     RenewTokenApi().get(bookingId: int.parse(widget.bookingId));
          // resp.then((value) {
          //   if (value['status'] == true) {
          //     rtcToken = value['agora_token'];
          //     channelName = value['channel_name'];
          //   }
          // });
        },
      ),
    );
    initAgr();
  }

  void initAgr() async {
    await _client.initialize().then((value) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  late final AgoraClient _client;

  // Create UI with local view and remote view
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        appBar: CustomWhiteAppBar(
          hasThreeDots: false,
          onThreeDotTap: () {},
          appBarText: 'Session',
          imgPath: "assets/images/iconbackappbarlarge.png",
        ),
        body: _isLoading
            ? Center(
                child: LoadingWidget(),
              )
            : Stack(children: [
                AgoraVideoViewer(
                  client: _client,
                  layoutType: Layout.oneToOne,
                ),
                AgoraVideoButtons(
                  client: _client,
                  autoHideButtons: true,
                  onDisconnect: () async {
                    log("message");
                    //await _client.release();
                    if (_isUser) {
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => USessionSuccessfulScreen(
                                    model: widget.model,
                                    bookingId: widget.bookingId,
                                    date: widget.date,
                                    issue: widget.issue,
                                  )));
                    } else {
                      final resp = await AvailabilityApi().get(status: 1);
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (ctx) => PSuccessfulSessionScreen()));
                    }
                  },
                ),
              ]),

        /*Stack(
          children: [
            _isLoading
                ? Center(
              child: LoadingWidget(),
            )
                : Center(
              child: _remoteVideo(),
            ),
            Positioned(
              top: 20,
              left: 10,
              child: SizedBox(
                width: 100,
                height: 150,
                child: Center(
                  child: _localUserJoined
                      ? AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: uid,),
                    ),
                  )
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
            //AgoraVideoButtons(client: _client, autoHideButtons: true,),
            Positioned(
              bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    RawMaterialButton(
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                        if(_isUser) {
                          _engine.muteRemoteAudioStream(uid: _remoteUid!, mute: _isMuted);
                        }else{
                          _engine.muteLocalAudioStream(_isMuted);
                        }
                      },
                      elevation: 2.0,
                      fillColor: Colors.white,
                      child: Icon(
                       _isMuted? Icons.mic_off : Icons.mic,
                        size: 20.0,
                        color: Colors.blueAccent,
                      ),
                      padding: EdgeInsets.all(15.0),
                      shape: CircleBorder(),
                    ),
                    RawMaterialButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      elevation: 2.0,
                      fillColor: Colors.redAccent,
                      child: Icon(
                        Icons.call_end,
                        size: 35.0,
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.all(15.0),
                      shape: CircleBorder(),
                    ),
                    RawMaterialButton(
                      onPressed: () {
                        _engine.switchCamera();
                      },
                      elevation: 2.0,
                      fillColor: Colors.white,
                      child: Icon(
                        Icons.switch_camera,
                        color: Colors.blueAccent,
                        size: 20.0,
                      ),
                      padding: EdgeInsets.all(15.0),
                      shape: CircleBorder(),
                    ),
                  ],
                ),
            ),
          ],
        ),*/
      ),
    );
  }
/*
  Widget _localPreview() {
    if (_isJoined) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: uid),
        ),
      );
    } else {
      return const Text(
        'Join a channel',
        textAlign: TextAlign.center,
      );
    }
  }

// Display remote user's video
  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: AgoraChatConfig.userId),
        ),
      );
    } else {
      String msg = 'Waiting for a remote user to join';
      //if (_isJoined) msg = 'Waiting for a remote user to join';
      return Text(
        msg,
        textAlign: TextAlign.center,
      );
    }
  }*/

/*void join() async {
    await _engine.startPreview();
    // Set channel options including the client role and channel profile

    ChannelMediaOptions options = const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    );

    await _engine
        .joinChannel(
      token: AgoraChatConfig.agoraToken,
      channelId: AgoraChatConfig.userId,
      options: options,
      uid: uid,
    )
        .then((value) {
      log("message");
    });
  }*/

/*void leave() {
    setState(() {
      _isJoined = false;
      _remoteUid = null;
    });
    _engine.leaveChannel();
  }*/
// Display remote user's video
/* Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: const RtcConnection(channelId: AgoraChatConfig.userId),
        ),
      );
    } else {
      return const Text(
        'Please wait for remote user to join',
        textAlign: TextAlign.center,
      );
    }
  }*/
}
