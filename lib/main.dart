import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DroidLensStreamer());
}

class DroidLensStreamer extends StatelessWidget {
  const DroidLensStreamer({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DroidLens Streamer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const StreamScreen(),
    );
  }
}

class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});
  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  CameraController? _camera;
  Socket? _socket;
  bool _sending = false;
  bool _streaming = false;
  int _framesSent = 0;
  int _lastSentMs = 0;
  String _status = 'Camera starting...';
  final TextEditingController _ipController =
      TextEditingController(text: '192.168.1.11');

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await Permission.camera.request();
    final cams = await availableCameras();
    if (cams.isEmpty) {
      setState(() => _status = 'No camera found!');
      return;
    }
    _camera = CameraController(
      cams.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _camera!.initialize();
    setState(() => _status = 'Camera ready. Enter PC IP and press CONNECT.');
  }

  Future<void> _toggleStream() async {
    if (_streaming) {
      await _camera?.stopImageStream();
      _socket?.close();
      setState(() {
        _streaming = false;
        _status = 'Stopped.';
      });
      return;
    }
    if (_camera == null || !_camera!.value.isInitialized) return;
    final ip = _ipController.text.trim();
    try {
      _socket = await Socket.connect(ip, 8276,
          timeout: const Duration(seconds: 5));
      setState(() => _status = 'Connected to PC! Streaming...');
      await _camera!.startImageStream((CameraImage frame) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastSentMs < 120) return; // ~8 fps throttle
        _lastSentMs = now;
        _sendFrame(frame);
      });
      setState(() => _streaming = true);
    } catch (e) {
      setState(() => _status = 'Connection failed: \$e');
    }
  }

  Future<void> _sendFrame(CameraImage frame) async {
    if (_sending || _socket == null) return;
    _sending = true;
    try {
      final rgb = _yuvToImage(frame);
      final jpeg =
          Uint8List.fromList(img.encodeJpg(rgb, quality: 70));
      final len = ByteData(4)..setInt32(0, jpeg.length, Endian.little);
      _socket!.add(len.buffer.asUint8List());
      _socket!.add(jpeg);
      await _socket!.flush();
      _framesSent++;
      if (_framesSent % 50 == 0) {
        setState(() => _status = 'Streaming... \$_framesSent frames sent');
      }
    } catch (_) {}
    _sending = false;
  }

  img.Image _yuvToImage(CameraImage image) {
    final w = image.width, h = image.height;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
    final out = img.Image(width: w, height: h);
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final yp = yPlane[y * w + x];
        final uvI = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;
        final up = uPlane[uvI];
        final vp = vPlane[uvI];
        int r = (yp + vp * 1436 / 1024 - 179).round();
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round();
        int b = (yp + up * 1814 / 1024 - 227).round();
        out.setPixelRgb(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
      }
    }
    return out;
  }

  @override
  void dispose() {
    _camera?.dispose();
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('DroidLens Streamer',
            style: TextStyle(color: Color(0xFF00F5FF))),
        backgroundColor: const Color(0xFF030712),
      ),
      body: Column(
        children: [
          Expanded(
            child: (_camera != null && _camera!.value.isInitialized)
                ? CameraPreview(_camera!)
                : const Center(child: CircularProgressIndicator()),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'PC ka IP (LAN BIND wala)',
                    labelStyle: TextStyle(color: Colors.cyan),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyan)),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _streaming
                              ? Colors.red
                              : const Color(0xFF00F5FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: _toggleStream,
                        child: Text(
                            _streaming ? 'STOP STREAM' : 'CONNECT & STREAM',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_status,
                    style: const TextStyle(
                        color: Color(0xFF00FF88), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
