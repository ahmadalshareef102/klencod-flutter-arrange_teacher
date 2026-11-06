import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'config.dart';

final InAppLocalhostServer server =
    InAppLocalhostServer(documentRoot: 'assets', port: serverPort);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await server.start();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Home()));
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6256AA),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest:
              URLRequest(url: WebUri(appUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            allowFileAccess: false,
            supportZoom: false,
            useHybridComposition: true,
          ),
          onWebViewCreated: (c) {
            c.addJavaScriptHandler(
              handlerName: 'saveFile',
              callback: (args) async {
                final bytes = Uint8List.fromList(utf8.encode(args[1] as String));
                await FilePicker.platform.saveFile(
                  fileName: args[0] as String,
                  bytes: bytes,
                );
                return true;
              },
            );
          },
          onPermissionRequest: (c, req) async {
            final st = await Permission.microphone.request();
            return PermissionResponse(
              resources: req.resources,
              action: st.isGranted
                  ? PermissionResponseAction.GRANT
                  : PermissionResponseAction.DENY,
            );
          },
          shouldOverrideUrlLoading: (c, a) async {
            final h = a.request.url?.host;
            return h == appHost
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL;
          },
        ),
      ),
    );
  }
}