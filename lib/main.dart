import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:telephony/telephony.dart';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late TextEditingController _controllerPeople,
      _controllerMessage,
      _controllerDomain;
  String? _message = "test",
      body;
  String _canSendSMSMessage = 'Check is not run.';
  List<String> people = [];
  String? domain;
  bool sendDirect = false;
  late StompClient client;
  late StompClient clientSmsSender;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    _controllerPeople = TextEditingController();
    _controllerMessage = TextEditingController();
    _controllerDomain = TextEditingController();
  }

  @override
  void dispose() {
    client.deactivate();
    clientSmsSender.deactivate();
    super.dispose();
  }

  void onConnect(StompFrame frame, Telephony telephony) {
    subscribeStompClient(client, telephony, '/otp', 'otp', (otpValues) {
      return '$otpValues is your one-time password to confirm your login.OTP is'
          'valid for 3 mins.';
    });
    subscribeStompClient(clientSmsSender, telephony, '/sms', 'message', (msg) {
      return msg;
    });
    // client.subscribe(
    //     destination: '/otp',
    //     callback: (StompFrame frame) {
    //       if (frame.body != null) {
    //         print('message received : ${frame.body}');
    //
    //         setState(() {
    //           _message = "----\n received msg: ${frame.body}; \n $_message";
    //         });
    //         final Map<String, dynamic> otpMessage = json.decode(frame.body!);
    //         final String otpSms = '${otpMessage['otp']} is your one-time '
    //             'password to confirm your login.OTP is valid for 3 mins.';
    //         telephony.sendSms(to: otpMessage['phoneNumber']!, message: otpSms);
    //
    //         print('message sent to ${frame.body}');
    //       }
    //     });
    // clientSmsSender.subscribe(
    //     destination: '/sms',
    //     callback: (StompFrame frame) {
    //       if (frame.body != null) {
    //         print('message received : ${frame.body}');
    //
    //         setState(() {
    //           _message = "----\n received msg: ${frame.body}; \n $_message";
    //         });
    //         final Map<String, dynamic> smsRequest = json.decode(frame.body!);
    //         telephony.sendSms(
    //             to: smsRequest['phoneNumber']!,
    //             message: smsRequest['message']
    //         );
    //
    //         print('message sent to ${frame.body}');
    //       }
    //     });
  }

  void subscribeStompClient(StompClient client,
      Telephony telephony,
      String wsPath,
      String msgKey,
      Function(String msg) getMessageAction) {
    client.subscribe(
        destination: wsPath,
        callback: (StompFrame frame) {
          if (frame.body != null) {
            print('wsMessage received : ${frame.body}');

            setState(() {
              _message = "----\n received msg: ${frame.body}; \n $_message";
            });
            final Map<String, dynamic> wsMessage = json.decode(frame.body!);
            String? phoneNumber = wsMessage['phoneNumber'];
            String? msg = getMessageAction(wsMessage[msgKey]);
            if (phoneNumber == null) {
              setState(() {
                _message =
                "----\n empty phone number: ${frame.body}; \n $_message";
              });
              return;
            } else if (msg == null) {
              setState(() {
                _message =
                "----\n empty msg: ${frame.body}; \n $_message";
              });
              return;
            }

            telephony.sendSms(to: wsMessage['phoneNumber']!, message: msg);
            print('wsMessage sent to ${frame.body}');
          }
        });
  }

  StompClient instantiateStompClient(Telephony telephony) {
    return StompClient(
        config: StompConfig.sockJS(
          url: 'http://$domain/websocket',
          onWebSocketError: (dynamic error) {
            setState(() {
              _message = "----\n error: $error; \n ${_message};";
            });
          },
          onConnect: (stompFrame) {
            print("connecting to websocket server");
            setState(() {
              _message =
              "----\n connected to websocket server; \n ${_message};";
            });
            onConnect(stompFrame, telephony);
          },
        ));
  }

  Widget _phoneTile(String name) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
          decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
                top: BorderSide(color: Colors.grey.shade300),
                left: BorderSide(color: Colors.grey.shade300),
                right: BorderSide(color: Colors.grey.shade300),
              )),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => people.remove(name)),
                ),
                Padding(
                  padding: const EdgeInsets.all(0),
                  child: Text(
                    name,
                    textScaleFactor: 1,
                    style: const TextStyle(fontSize: 12),
                  ),
                )
              ],
            ),
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Telephony telephony = Telephony.instance;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SMS/MMS Example'),
        ),
        body: ListView(
          children: <Widget>[
            if (people.isEmpty)
              const SizedBox(height: 0)
            else
              SizedBox(
                height: 90,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: List<Widget>.generate(people.length, (int index) {
                      return _phoneTile(people[index]);
                    }),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.people),
              title: TextField(
                controller: _controllerPeople,
                decoration:
                const InputDecoration(labelText: 'Add Phone Number'),
                keyboardType: TextInputType.number,
                onChanged: (String value) => setState(() {}),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                onPressed: _controllerPeople.text.isEmpty
                    ? null
                    : () =>
                    setState(() {
                      people.add(_controllerPeople.text.toString());
                      _controllerPeople.clear();
                    }),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.message),
              title: TextField(
                decoration: const InputDecoration(labelText: 'Add Message'),
                controller: _controllerMessage,
                onChanged: (String value) => setState(() {}),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Can send SMS'),
              subtitle: Text(_canSendSMSMessage),
              trailing: IconButton(
                padding: const EdgeInsets.symmetric(vertical: 16),
                icon: const Icon(Icons.check),
                onPressed: () async {
                  bool? permissionsGranted =
                  await telephony.requestSmsPermissions;

                  setState(() {
                    _message =
                    "----\n is granted: $permissionsGranted; \n $_message";
                  });
                },
              ),
            ),
            SwitchListTile(
                title: const Text('Send Direct'),
                subtitle: const Text(
                    'Should we skip the additional dialog? (Android only)'),
                value: sendDirect,
                onChanged: (bool newValue) {
                  setState(() {
                    sendDirect = newValue;
                  });
                }),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith(
                          (states) =>
                      Theme
                          .of(context)
                          .colorScheme
                          .secondary),
                  padding: MaterialStateProperty.resolveWith(
                          (states) => const EdgeInsets.symmetric(vertical: 16)),
                ),
                onPressed: () async {
                  try {
                    await telephony.sendSms(
                        to: people.first, message: 'No Data');
                  } catch (e) {
                    _message = "----\n error; $e \n $_message";
                  }
                  setState(() {
                    _message = "----\n sent msg; \n $_message";
                  });
                },
                child: Text(
                  'SEND',
                  style: Theme
                      .of(context)
                      .textTheme
                      .displayMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: TextField(
                controller: _controllerDomain,
                decoration: const InputDecoration(labelText: 'IP and Port'),
                keyboardType: TextInputType.number,
                onChanged: (String value) => setState(() {}),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add),
                onPressed: _controllerDomain.text.isEmpty
                    ? null
                    : () =>
                    setState(() {
                      domain = _controllerDomain.text.toString();
                      setState(() {
                        _message =
                        "----\n domain set: ${_controllerDomain.text
                            .toString()}  \n $_message";
                      });
                      // _controllerDomain.clear();
                    }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith(
                          (states) =>
                      Theme
                          .of(context)
                          .colorScheme
                          .secondary),
                  padding: MaterialStateProperty.resolveWith(
                          (states) => const EdgeInsets.symmetric(vertical: 16)),
                ),
                onPressed: () {
                  final Telephony telephony = Telephony.instance;

                  client = instantiateStompClient(telephony);
                  client.activate();
                  clientSmsSender = instantiateStompClient(telephony);
                  clientSmsSender.activate();

                  // telephony.sendSms(
                  //     to: people.first,
                  //     message: _message ?? 'No Data'
                  // );
                },
                child: Text(
                  'CONNECT WS',
                  style: Theme
                      .of(context)
                      .textTheme
                      .displayMedium,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith(
                          (states) =>
                      Theme
                          .of(context)
                          .colorScheme
                          .secondary),
                  padding: MaterialStateProperty.resolveWith(
                          (states) => const EdgeInsets.symmetric(vertical: 16)),
                ),
                onPressed: () {
                  client.deactivate();
                  clientSmsSender.deactivate();
                },
                child: Text(
                  'Deactivate ws',
                  style: Theme
                      .of(context)
                      .textTheme
                      .displayMedium,
                ),
              ),
            ),
            Visibility(
              visible: _message != null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _message ?? 'No Data',
                        maxLines: null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
