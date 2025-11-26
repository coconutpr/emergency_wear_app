import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const EmergencyWearApp());
}

class EmergencyWearApp extends StatelessWidget {
  const EmergencyWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOS Wear',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
      ),
      debugShowCheckedModeBanner: false,
      home: const EmergencyHomePage(),
    );
  }
}

// -----------------------------------------------------------------------------
// HOME PAGE (BOTÓN SOS)
// -----------------------------------------------------------------------------
class EmergencyHomePage extends StatefulWidget {
  const EmergencyHomePage({super.key});

  @override
  State<EmergencyHomePage> createState() => _EmergencyHomePageState();
}

class _EmergencyHomePageState extends State<EmergencyHomePage>
    with SingleTickerProviderStateMixin {
  bool _countingDown = false;
  int _countdown = 3;
  Timer? _timer;

  late AnimationController _pulseController;

  String _emergencyNumber = "";
  Position? _lastPosition;

  final String _messagePrefix = "SOS: necesito ayuda. Mi ubicación:";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.9,
      upperBound: 1.1,
    )..repeat(reverse: true);

    _loadNumber();
    _ensurePermissions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadNumber() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emergencyNumber = prefs.getString("emergencyNumber") ?? "";
    });
  }

  Future<void> _saveNumber(String number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("emergencyNumber", number);
    setState(() => _emergencyNumber = number);
  }

  Future<void> _ensurePermissions() async {
    await Permission.location.request();
  }

  Future<void> _getLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        debugPrint("GPS apagado");
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          debugPrint("Permiso denegado");
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        debugPrint("Permiso denegado permanentemente");
        return;
      }

      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      debugPrint("Ubicación obtenida: $_lastPosition");
    } catch (e) {
      debugPrint("Error obteniendo ubicación: $e");
    }
  }

  Future<void> _sendSOS() async {
    if (_emergencyNumber.isEmpty) {
      _openNumberConfig();
      return;
    }

    await _getLocation();

    final coords = _lastPosition != null
        ? "https://maps.google.com/?q=${_lastPosition!.latitude},${_lastPosition!.longitude}"
        : "ubicación no disponible";

    final msg = "$_messagePrefix $coords";

    // SMS
    final smsUri = Uri.parse("sms:$_emergencyNumber?body=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(smsUri)) await launchUrl(smsUri);

    // WhatsApp
    final waUri = Uri.parse("https://wa.me/$_emergencyNumber?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(waUri)) await launchUrl(waUri);

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 200, 100, 300]);
    }
  }

  void _startCountdown() {
    if (_countingDown) return;

    setState(() {
      _countingDown = true;
      _countdown = 3;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        setState(() => _countingDown = false);
        _sendSOS();
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() {
      _countingDown = false;
      _countdown = 3;
    });
  }

  void _openNumberConfig() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NumberConfigPage(
          initialValue: _emergencyNumber,
          onSave: _saveNumber,
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------------  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.shortestSide * 0.9;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ClipOval(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                GestureDetector(
                  onLongPressStart: (_) => _startCountdown(),
                  onLongPressEnd: (_) => _cancelCountdown(),
                  child: ScaleTransition(
                    scale: _pulseController,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Colors.red, Colors.black87],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _countingDown ? "$_countdown" : "SOS",
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: _openNumberConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text("Configurar número"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA CONFIGURAR NÚMERO
// -----------------------------------------------------------------------------
class NumberConfigPage extends StatefulWidget {
  final String initialValue;
  final Function(String) onSave;

  const NumberConfigPage({
    super.key,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<NumberConfigPage> createState() => _NumberConfigPageState();
}

class _NumberConfigPageState extends State<NumberConfigPage> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Número de emergencia",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: size.width * 0.75,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: "+34600111222",
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.redAccent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onSave(_controller.text.trim());
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text("Guardar"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
