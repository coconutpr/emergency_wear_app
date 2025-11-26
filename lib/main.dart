import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const EmergencyWearApp());
}

class EmergencyWearApp extends StatelessWidget {
  const EmergencyWearApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOS Wear',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
      ),
      home: const EmergencyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class EmergencyHomePage extends StatefulWidget {
  const EmergencyHomePage({Key? key}) : super(key: key);

  @override
  State<EmergencyHomePage> createState() => _EmergencyHomePageState();
}

class _EmergencyHomePageState extends State<EmergencyHomePage> {
  bool _sosActive = false;
  bool _countingDown = false;
  int _countdown = 3;
  Timer? _countdownTimer;

  // sensors
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;

  // location
  Position? _lastPosition;

  final String _emergencyNumber = "";
  final String _emergencyMessagePrefix = "SOS: necesito ayuda. Mi ubicación: ";

  @override
  void initState() {
    super.initState();
    _startSensors();
    _ensurePermissions();
  }

  @override
  void dispose() {
    _accSub?.cancel();
    _gyroSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    await Permission.locationWhenInUse.request();
  }

  void _startSensors() {
    _accSub = accelerometerEvents.listen((AccelerometerEvent e) {
      setState(() {
        _ax = e.x;
        _ay = e.y;
        _az = e.z;
      });
    });
    _gyroSub = gyroscopeEvents.listen((GyroscopeEvent e) {
      setState(() {
        _gx = e.x;
        _gy = e.y;
        _gz = e.z;
      });
    });
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _lastPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  void _vibrateStrong() {
    Vibration.hasVibrator().then((has) {
      if (has ?? false) {
        Vibration.vibrate(pattern: [0, 200, 100, 400]);
      }
    });
  }

  Future<void> _sendSOS() async {
    setState(() => _sosActive = true);
    await _getLocation();

    final coords = _lastPosition != null
        ? "https://maps.google.com/?q=${_lastPosition!.latitude},${_lastPosition!.longitude}"
        : "ubicación no disponible";

    final message = "$_emergencyMessagePrefix $coords";

    final smsUri =
        Uri.parse("sms:$_emergencyNumber?body=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }

    _vibrateStrong();
  }

  void _startCountdown() {
    if (_countingDown) return;
    setState(() {
      _countingDown = true;
      _countdown = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);

      if (_countdown <= 0) {
        t.cancel();
        setState(() => _countingDown = false);
        _sendSOS();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countingDown = false;
      _countdown = 3;
    });
  }

  Widget _buildCircularLayout(BuildContext context) {
    final double size = MediaQuery.of(context).size.shortestSide * 0.9;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Container(
            color: Theme.of(context).colorScheme.background,
            child: _buildInnerContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildInnerContent(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onLongPressStart: (_) => _startCountdown(),
          onLongPressEnd: (_) => _cancelCountdown(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.red.shade400, Colors.red.shade800],
                  ),
                  boxShadow: const [
                    BoxShadow(blurRadius: 8, spreadRadius: 1)
                  ],
                ),
              ),
              _countingDown
                  ? Text(
                      "$_countdown",
                      style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Text(
                      "SOS",
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sosActive
            ? const Text("SOS activado", style: TextStyle(color: Colors.red))
            : const Text("Mantén pulsado para lanzar SOS"),

        const SizedBox(height: 12),
        Text("Acc: ${_ax.toStringAsFixed(2)}, ${_ay.toStringAsFixed(2)}, ${_az.toStringAsFixed(2)}"),
        Text("Gyr: ${_gx.toStringAsFixed(2)}, ${_gy.toStringAsFixed(2)}, ${_gz.toStringAsFixed(2)}"),

        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => setState(() => _sosActive = false),
          child: const Text("Desactivar SOS"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRound = MediaQuery.of(context).size.aspectRatio <= 1.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: isRound
            ? _buildCircularLayout(context)
            : _buildInnerContent(context),
      ),
    );
  }
}
