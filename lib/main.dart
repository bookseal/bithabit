import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error in fetching the cameras: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BitHabit Camera',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  Timer? _timer;
  bool _isCapturing = false;
  int _countdown = 3;
  int _selectedCameraIndex = 0;
  Stopwatch _stopwatch = Stopwatch();
  Timer? _stopwatchTimer;
  int _captureInterval = 3;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopCapturing();
    controller?.dispose();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      _isCameraPermissionGranted = await _requestCameraPermissionWeb();
    } else {
      // 모바일 플랫폼을 위한 권한 요청 로직 (필요시 추가)
      _isCameraPermissionGranted = true;
    }

    if (!_isCameraPermissionGranted) {
      _showSnackBar('Camera permission is required');
      return;
    }

    if (cameras.isEmpty) {
      _showSnackBar('No camera available');
      return;
    }

    await _initializeCameraAtIndex(0);
  }

  Future<void> _initializeCameraAtIndex(int index) async {
    if (controller != null) {
      await controller!.dispose();
    }

    controller = CameraController(cameras[index], ResolutionPreset.max);

    try {
      await controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _selectedCameraIndex = index;
        });
      }
    } on CameraException catch (e) {
      _showSnackBar('Error initializing camera: ${e.description}');
    }
  }

  Future<bool> _requestCameraPermissionWeb() async {
    final permissions =
        await html.window.navigator.permissions?.query({'name': 'camera'});
    return permissions?.state == 'granted';
  }

  void _toggleCapturing() {
    setState(() {
      _isCapturing = !_isCapturing;
      if (_isCapturing) {
        _startTime = DateTime.now();
        _endTime = null;
        _startStopwatch();
        _startCapturing();
      } else {
        _endTime = DateTime.now();
        _stopStopwatch();
        _stopCapturing();
      }
    });
  }

  void _startCapturing() {
    _countdown = _captureInterval;
    _timer = Timer.periodic(const Duration(seconds: 1), _handleCapturingTick);
  }

  void _stopCapturing() {
    _timer?.cancel();
    _timer = null;
    setState(() => _countdown = _captureInterval);
  }

  void _handleCapturingTick(Timer timer) {
    setState(() {
      if (_countdown > 0) {
        _countdown--;
      } else {
        _countdown = _captureInterval;
        _takePictureAndDownload();
      }
    });
  }

  void _startStopwatch() {
    _stopwatch.start();
    _stopwatchTimer = Timer.periodic(
        const Duration(milliseconds: 100), (_) => setState(() {}));
  }

  void _stopStopwatch() {
    _stopwatch.stop();
    _stopwatchTimer?.cancel();
  }

  String _formatStopwatchTime() {
    var milliseconds = _stopwatch.elapsedMilliseconds;
    int hundreds = (milliseconds / 10).truncate();
    int seconds = (hundreds / 100).truncate();
    int minutes = (seconds / 60).truncate();

    return "${(minutes % 60).toString().padLeft(2, '0')}:"
        "${(seconds % 60).toString().padLeft(2, '0')}:"
        "${(hundreds % 100).toString().padLeft(2, '0')}";
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--:--';
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  Future<void> _takePictureAndDownload() async {
    if (controller == null || !controller!.value.isInitialized) {
      _showSnackBar('Camera is not initialized');
      return;
    }

    try {
      final XFile image = await controller!.takePicture();
      final Uint8List bytes = await image.readAsBytes();
      final String fileName =
          '${path.basenameWithoutExtension(image.path)}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (kIsWeb) {
        await _downloadImageWeb(bytes, fileName);
      } else {
        // 모바일 플랫폼을 위한 이미지 저장 로직 (필요시 추가)
      }
      _showSnackBar('Picture saved as $fileName');
    } catch (e) {
      _showSnackBar('Error taking picture: $e');
    }
  }

  Future<void> _downloadImageWeb(Uint8List bytes, String fileName) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body!.children.add(anchor);

    anchor.click();

    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  void _switchCamera() {
    if (cameras.length < 2) return;
    final nextIndex = (_selectedCameraIndex + 1) % cameras.length;
    _initializeCameraAtIndex(nextIndex);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('BitHabit Camera')),
      body: Stack(
        children: [
          _buildCameraPreview(),
          if (_isCapturing) _buildCountdownOverlay(),
          _buildTimeDisplay(),
          _buildIntervalSelector(),
          if (!kIsWeb) _buildCameraSwitchButton(),
        ],
      ),
      floatingActionButton: _buildCaptureButton(),
    );
  }

  Widget _buildCameraPreview() {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CameraPreview(controller!),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Center(
      child: Text(
        _countdown > 0 ? _countdown.toString() : 'Shot!',
        style: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
                blurRadius: 10.0, color: Colors.black, offset: Offset(5.0, 5.0))
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSwitchButton() {
    return Positioned(
      top: 20,
      right: 20,
      child: FloatingActionButton(
        child: Icon(Icons.switch_camera),
        mini: true,
        onPressed: _switchCamera,
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return Positioned(
      top: 20,
      left: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start: ${_formatDateTime(_startTime)}',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              'End: ${_formatDateTime(_endTime)}',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              'Duration: ${_isCapturing ? _formatStopwatchTime() : _formatStopwatchTime()}',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Positioned(
      bottom: 20,
      left: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text('Interval: ', style: TextStyle(color: Colors.white)),
            DropdownButton<int>(
              value: _captureInterval,
              dropdownColor: Colors.black.withOpacity(0.7),
              style: TextStyle(color: Colors.white),
              underline: Container(),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  setState(() {
                    _captureInterval = newValue;
                    _countdown = newValue;
                  });
                }
              },
              items: <int>[1, 2, 3, 5, 10, 15, 30, 60]
                  .map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value s'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return FloatingActionButton(
      child: Icon(_isCapturing ? Icons.stop : Icons.camera),
      onPressed: _toggleCapturing,
    );
  }
}
