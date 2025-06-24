import 'dart:convert';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';

import 'anim_painter.dart'; // Add this import

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool onMic = true;
  bool isRecording = false;
  bool isProcessing = false; // Track processing state
  bool quantumMode = false;
  final AudioRecorder audioRecorder = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer(); // Audio player instance
  String? recordingPath;
  String text = 'مرحباً، أنا أنس\n.وأنا هنا لمساعدتك';
  String? answer;
  // Server URL (adjust for your environment)
  final _serverURL = "http://192.168.1.3:8000/predict/text/audio";
  final textController = TextEditingController();
  @override
  void dispose() {
    audioRecorder.dispose();
    audioPlayer.dispose(); // Dispose audio player
    super.dispose();
  }

  // Send audio to server and play response
  Future<void> _sendAudioToServer(String filePath) async {
    setState(() => isProcessing = true);

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_serverURL));
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio_file',
          filePath,
          contentType: MediaType("audio", "wav"),
          filename: p.basename(filePath),
        ),
      );
      final response = await request.send();

      if (response.statusCode == 200) {
        final base64Str = await response.stream.bytesToString();
        final bytesReplaced = base64Str.replaceAll('"', '');
        final bytes = base64Decode(bytesReplaced);
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/response_audio.wav');
        await tempFile.writeAsBytes(bytes);
        await audioPlayer.play(DeviceFileSource(tempFile.path));
        setState(() {
          text = '';
        });
      } else {
        print('Server error: ${response.statusCode}');
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<void> getAnswer() async {
    final url = Uri.parse("http://192.168.1.3:8000/predict/text");
    print(textController.text);
    final response = await http.post(
      url,
      body: jsonEncode({"question": textController.text}),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      setState(() {
        text = response.body;
      });

      await getAnswerAudio(answer: response.body);
    }
  }

  Future<void> getAnswerAudio({required String answer}) async {
    final url = Uri.parse("http://192.168.1.3:8000/predict/audio");
    final response = await http.post(
      url,
      body: jsonEncode({"answer": answer}),
      headers: {"Content-Type": "application/json"},
    );

    final base64Str = response.body;
    final bytesReplaced = base64Str.replaceAll('"', '');
    final bytes = base64Decode(bytesReplaced);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/response_audio.wav');
    await tempFile.writeAsBytes(bytes);
    await audioPlayer.play(DeviceFileSource(tempFile.path));
  }

  String adaptiveText() {
    if (isRecording) {
      return ".."
          "...أسمعك";
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1818),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        text != ''
                            ? Text(
                                adaptiveText(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontFamily: GoogleFonts.cairo().fontFamily,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : SizedBox.shrink(),
                      ],
                    ),
                  ),

                  // Main Section
                  if (onMic)
                    AnimatedRecordingCircle(isRecording: isRecording)
                  else
                    Column(
                      children: [
                        SizedBox(height: 20),
                        Container(
                          width: 300,
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(0xFFD9D9D9),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: TextFormField(
                            controller: textController,
                            onEditingComplete: () => getAnswer(),
                            onSaved: (_) => getAnswer(),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontSize: 19),
                            decoration: InputDecoration(
                              hintText: '...كيف يمكنني مساعدتك',
                              hintStyle: TextStyle(color: Color(0xB01A1818)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Footer
                  Column(
                    children: [
                      if (onMic)
                        GestureDetector(
                          onTap: () async {
                            if (isRecording) {
                              // Stop recording
                              String? filePath = await audioRecorder.stop();
                              print("Stopped Filepath: ${filePath}");
                              if (filePath != null) {
                                setState(() {
                                  isRecording = false;
                                  recordingPath = filePath;
                                });
                                await _sendAudioToServer(
                                  filePath,
                                ); // Send to server
                              }
                            } else {
                              // Start recording
                              if (await audioRecorder.hasPermission()) {
                                final appDirectory =
                                    await getDownloadsDirectory();
                                final String filePath =
                                    "${appDirectory!.path}/recording.wav";
                                await audioRecorder.start(
                                  const RecordConfig(encoder: AudioEncoder.wav),
                                  path: filePath,
                                );
                                setState(() {
                                  isRecording = true;
                                  recordingPath = null;
                                });
                              }
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Mic / Close Button
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isRecording
                                      ? Colors.red
                                      : Color(0xFFD9D9D9),
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.asset(
                                  isRecording
                                      ? 'assets/images/close.svg'
                                      : 'assets/images/microphone.svg',
                                  width: 40,
                                  height: 40,
                                  color: Color(0xFF1A1818),
                                ),
                              ),

                              // Quantum Button
                            ],
                          ),
                        ),
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 25,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFD9D9D9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => onMic = true),
                              child: Container(
                                padding: EdgeInsets.all(15),
                                decoration: onMic
                                    ? BoxDecoration(
                                        color: Color(0xFF1A1818),
                                        shape: BoxShape.circle,
                                      )
                                    : null,
                                child: SvgPicture.asset(
                                  'assets/images/mic.svg',
                                  width: 30,
                                  height: 30,
                                  color: onMic
                                      ? Colors.white
                                      : Color(0xFF1A1818),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => quantumMode = !quantumMode),
                              child: Container(
                                padding: EdgeInsets.all(15),
                                child: SvgPicture.asset(
                                  quantumMode
                                      ? 'assets/images/on-button.svg'
                                      : 'assets/images/off-button.svg',
                                  width: 50,
                                  height: 50,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => onMic = false),
                              child: Container(
                                padding: EdgeInsets.all(15),
                                decoration: !onMic
                                    ? BoxDecoration(
                                        color: Color(0xFF1A1818),
                                        shape: BoxShape.circle,
                                      )
                                    : null,
                                child: SvgPicture.asset(
                                  'assets/images/chat.svg',
                                  width: 30,
                                  height: 30,
                                  color: onMic
                                      ? Color(0xFF1A1818)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Loading indicator
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}



// import 'dart:convert';
// import 'dart:io';
// import 'package:anasai/anim_painter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:http_parser/http_parser.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:record/record.dart';
// import 'package:path/path.dart' as p;
// import 'package:audioplayers/audioplayers.dart';

// void main() => runApp(MyApp());

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen());
//   }
// }

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   bool onMic = true;
//   bool isRecording = false;
//   bool isProcessing = false; // Track processing state
//   bool quantumMode = false;
//   final AudioRecorder audioRecorder = AudioRecorder();
//   final AudioPlayer audioPlayer = AudioPlayer(); // Audio player instance
//   String? recordingPath;
//   String? answer;
//   // Server URL (adjust for your environment)
//   final _serverURL = "http://192.168.1.2:8000/predict/text/audio";
//   final textController = TextEditingController();
//   @override
//   void dispose() {
//     audioRecorder.dispose();
//     audioPlayer.dispose(); // Dispose audio player
//     super.dispose();
//   }

//   // Send audio to server and play response
//   Future<void> _sendAudioToServer(String filePath) async {
//     setState(() => isProcessing = true);

//     try {
//       final request = http.MultipartRequest('POST', Uri.parse(_serverURL));
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'audio_file',
//           filePath,
//           contentType: MediaType("audio", "wav"),
//           filename: p.basename(filePath),
//         ),
//       );
//       final response = await request.send();

//       if (response.statusCode == 200) {
//         final base64Str = await response.stream.bytesToString();
//         final bytesReplaced = base64Str.replaceAll('"', '');
//         final bytes = base64Decode(bytesReplaced);
//         final tempDir = await getTemporaryDirectory();
//         final tempFile = File('${tempDir.path}/response_audio.wav');
//         await tempFile.writeAsBytes(bytes);
//         await audioPlayer.play(DeviceFileSource(tempFile.path));
//       } else {
//         print('Server error: ${response.statusCode}');
//       }
//     } finally {
//       if (mounted) setState(() => isProcessing = false);
//     }
//   }

//   Future<void> getAnswer() async {
//     final url = Uri.parse("http://192.168.1.2:8000/predict/text");
//     print(textController.text);
//     final response = await http.post(
//       url,
//       body: jsonEncode({"question": textController.text}),
//       headers: {"Content-Type": "application/json"},
//     );
//     print(response.body);

//     if (response.statusCode == 200) {
//       setState(() {
//         answer = response.body;
//       });
//       await getAnswerAudio(answer: response.body);
//     }
//   }

//   Future<void> getAnswerAudio({required String answer}) async {
//     final url = Uri.parse("http://192.168.1.2:8000/predict/audio");
//     print(textController.text);
//     final response = await http.post(
//       url,
//       body: jsonEncode({"answer": answer}),
//       headers: {"Content-Type": "application/json"},
//     );

//     final base64Str = response.body;
//     final bytesReplaced = base64Str.replaceAll('"', '');
//     final bytes = base64Decode(bytesReplaced);
//     final tempDir = await getTemporaryDirectory();
//     final tempFile = File('${tempDir.path}/response_audio.wav');
//     await tempFile.writeAsBytes(bytes);
//     await audioPlayer.play(DeviceFileSource(tempFile.path));
//   }

//   String adaptiveText() {
//     if (answer != null) {
//       return answer!;
//     }
//     if (isRecording) {
//       return ".."
//           "سامعك";
//     }
//     return 'مرحباً، أنا أنس\n.وأنا هنا لمساعدتك';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xFF1A1818),
//       body: Stack(
//         children: [
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   // Header
//                   Center(
//                     child: Column(
//                       children: [
//                         Text(
//                           adaptiveText(),
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 26,
//                             fontFamily: GoogleFonts.cairo().fontFamily,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   // Main Section
//                   if (onMic)
//                     AnimatedRecordingCircle(isRecording: isRecording)
//                   else
//                     Column(
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
                         
//                         ),
//                         SizedBox(height: 20),
//                         Container(
//                           width: 300,
//                           padding: EdgeInsets.all(20),
//                           decoration: BoxDecoration(
//                             color: Color(0xFFD9D9D9),
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                           child: TextFormField(
//                             controller: textController,
//                             onEditingComplete: () => getAnswer(),
//                             onSaved: (_) => getAnswer(),
//                             textAlign: TextAlign.right,
//                             textDirection: TextDirection.rtl,
//                             style: TextStyle(fontSize: 19),
//                             decoration: InputDecoration(
//                               hintText: '...كيف يمكنني مساعدتك',
//                               hintStyle: TextStyle(color: Color(0xB01A1818)),
//                               border: InputBorder.none,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   Column(
//                     children: [
//                       if (onMic)
//                         GestureDetector(
//                           onTap: () async {
//                             if (isRecording) {
//                               String? filePath = await audioRecorder.stop();
//                               if (filePath != null) {
//                                 setState(() {
//                                   isRecording = false;
//                                   recordingPath = filePath;
//                                 });
//                                 await _sendAudioToServer(
//                                   filePath,
//                                 ); // Send to server
//                               }
//                             } else {
//                               if (await audioRecorder.hasPermission()) {
//                                 final appDirectory =
//                                     await getDownloadsDirectory();
//                                 final String filePath =
//                                     "${appDirectory!.path}/recording.wav";
//                                 await audioRecorder.start(
//                                   const RecordConfig(encoder: AudioEncoder.wav),
//                                   path: filePath,
//                                 );
//                                 setState(() {
//                                   isRecording = true;
//                                   recordingPath = null;
//                                 });
//                               }
//                             }
//                           },
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               GestureDetector(
//                                 onTap: () =>
//                                     setState(() => isRecording = !isRecording),
//                                 child: AnimatedContainer(
//                                   duration: Duration(milliseconds: 300),
//                                   padding: EdgeInsets.all(10),
//                                   decoration: BoxDecoration(
//                                     color: isRecording
//                                         ? Colors.red
//                                         : Color(0xFFD9D9D9),
//                                     shape: BoxShape.circle,
//                                   ),
//                                   child: SvgPicture.asset(
//                                     isRecording
//                                         ? 'assets/images/close.svg'
//                                         : 'assets/images/microphone.svg',
//                                     width: 40,
//                                     height: 40,
//                                     colorFilter: ColorFilter.mode(
//                                       Color(0xFF1A1818),
//                                       BlendMode.srcIn,
//                                     ),
//                                   ),
//                                 ),
//                               ),

//                               // Quantum Button
                             
//                             ],
//                           ),
//                         ),
//                       SizedBox(height: 20),
//                       Container(
//                         padding: EdgeInsets.symmetric(
//                           vertical: 15,
//                           horizontal: 25,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Color(0xFFD9D9D9),
//                           borderRadius: BorderRadius.circular(15),
//                         ),
//                           child: Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             GestureDetector(
//                               onTap: () => setState(() => onMic = true),
//                               child: Container(
//                                 padding: EdgeInsets.all(15),
//                                 decoration: onMic
//                                     ? BoxDecoration(
//                                         color: Color(0xFF1A1818),
//                                         shape: BoxShape.circle,
//                                       )
//                                     : null,
//                                 child: SvgPicture.asset(
//                                   'assets/images/mic.svg',
//                                   width: 30,
//                                   height: 30,
//                                   color: onMic
//                                       ? Colors.white
//                                       : Color(0xFF1A1818),
//                                 ),
//                               ),
//                             ),
//                             GestureDetector(
//                               onTap: () => setState(() => quantumMode = !quantumMode),
//                               child: Container(
//                                 padding: EdgeInsets.all(15),
//                                 child: SvgPicture.asset(
//                                   quantumMode
//                                       ? 'assets/images/on-button.svg'
//                                       : 'assets/images/off-button.svg',
//                                   width: 50,
//                                   height: 50,
                                
//                                 ),
//                               ),
//                             ),
//                             GestureDetector(
//                               onTap: () => setState(() => onMic = false),
//                               child: Container(
//                                 padding: EdgeInsets.all(15),
//                                 decoration: !onMic
//                                     ? BoxDecoration(
//                                         color: Color(0xFF1A1818),
//                                         shape: BoxShape.circle,
//                                       )
//                                     : null,
//                                 child: SvgPicture.asset(
//                                   'assets/images/chat.svg',
//                                   width: 30,
//                                   height: 30,
//                                   color: onMic
//                                       ? Color(0xFF1A1818)
//                                       : Colors.white,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           // Loading indicator
//           if (isProcessing)
//             Container(
//               color: Colors.black54,
//               child: Center(child: CircularProgressIndicator()),
//             ),
//         ],
//       ),
//     );
//   }
// }