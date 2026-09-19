import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const DroidLensApp());
}

class DroidLensApp extends StatelessWidget {
  const DroidLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DroidLens HUD',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F5FF),
          secondary: Color(0xFF9D00FF),
          surface: Color(0xFF0D1117),
        ),
      ),
      home: const StreamHudPreviewScreen(),
    );
  }
}

class StreamHudPreviewScreen extends StatefulWidget {
  const StreamHudPreviewScreen({super.key});

  @override
  State<StreamHudPreviewScreen> createState() => _StreamHudPreviewScreenState();
}

class _StreamHudPreviewScreenState extends State<StreamHudPreviewScreen>
    with TickerProviderStateMixin {
  bool _isStreaming = true;
  bool _isFrontCamera = false;
  bool _isTorchOn = false;
  bool _isMuted = false;
  bool _isAFLocked = true;
  bool _isLandscapeLocked = false;
  String _resolution = '1080p';
  double _zoomLevel = 1.0;
  double _exposureVal = 0.0;

  int _fps = 60;
  int _bitrateKbps = 14250;
  int _latencyMs = 18;
  int _batteryPct = 84;
  double _batteryTempC = 33.5;
  int _dataUsageMb = 482;
  Duration _sessionDuration = const Duration(minutes: 18, seconds: 42);
  Timer? _telemetryTimer;

  late AnimationController _pulseController;
  late AnimationController _radarController;
  late AnimationController _reticleController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _reticleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _sessionDuration += const Duration(seconds: 1);
        _latencyMs = 16 + math.Random().nextInt(6);
        _fps = 58 + math.Random().nextInt(4);
        _bitrateKbps = 14100 + math.Random().nextInt(400);
      });
    });
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _pulseController.dispose();
    _radarController.dispose();
    _reticleController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  void _showQualityModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0B132B).withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFF00F5FF).withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F5FF).withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFF00F5FF), size: 20),
                const SizedBox(width: 8),
                Text(
                  'STREAM RESOLUTION & ENCODING',
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              '4K (2160p 30FPS - 25 Mbps)',
              'FHD (1080p 60FPS - 14 Mbps)',
              'HD (720p 60FPS - 6 Mbps)',
              'SD (480p 30FPS - 2 Mbps)'
            ].map((opt) {
              final label = opt.split(' ')[0];
              final isSelected = _resolution.contains(label);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00F5FF).withOpacity(0.15)
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00F5FF)
                        : Colors.white10,
                  ),
                ),
                child: ListTile(
                  title: Text(opt,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF00F5FF), size: 18)
                      : null,
                  onTap: () {
                    setState(() => _resolution = label);
                    Navigator.pop(ctx);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Color(0xFF0E1A2B),
                    Color(0xFF050B14),
                    Color(0xFF010408),
                  ],
                ),
              ),
              child: CustomPaint(
                painter: GridBackgroundPainter(),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _reticleController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(260, 260),
                  painter: HudReticlePainter(
                    angle: _reticleController.value * 2 * math.pi,
                    isLocked: _isAFLocked,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 110,
            child: !_isMuted
                ? SizedBox(
                    height: 28,
                    child: AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(28, (index) {
                            final h = (math.sin(index * 0.4 +
                                        _waveController.value *
                                            2 *
                                            math.pi +
                                        index * 0.35) *
                                    12 +
                                14)
                                .abs();
                            return Container(
                              width: 3,
                              height: h,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2.5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xFF00F5FF),
                                    Color(0xFF9D00FF)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic_off,
                              color: Colors.redAccent, size: 14),
                          SizedBox(width: 6),
                          Text('AUDIO TRANSMISSION MUTED',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.redAccent,
                                  letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isStreaming
                            ? const Color(0xFF00F5FF).withOpacity(0.12)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isStreaming
                              ? const Color(0xFF00F5FF)
                              : Colors.grey,
                          width: 1.2,
                        ),
                        boxShadow: _isStreaming
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00F5FF)
                                      .withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeTransition(
                            opacity: _pulseController,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isStreaming
                                    ? const Color(0xFF00F5FF)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isStreaming ? 'LIVE // mTLS 1.3' : 'STANDBY',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: _isStreaming
                                  ? const Color(0xFF00F5FF)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 13, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            _formatDuration(_sessionDuration),
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _batteryPct > 20
                                ? Icons.battery_charging_full_rounded
                                : Icons.battery_alert_rounded,
                            size: 14,
                            color: _batteryPct > 20
                                ? const Color(0xFF00FF88)
                                : Colors.redAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_batteryPct% • ${_batteryTempC.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090E17).withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF00F5FF).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                          'FPS', '$_fps', const Color(0xFF00F5FF)),
                      _buildDivider(),
                      _buildMetricItem(
                          'LATENCY',
                          '$_latencyMs ms',
                          _latencyMs < 25
                              ? const Color(0xFF00FF88)
                              : Colors.orangeAccent),
                      _buildDivider(),
                      _buildMetricItem(
                          'BITRATE',
                          '${(_bitrateKbps / 1000).toStringAsFixed(1)} Mb/s',
                          Colors.white),
                      _buildDivider(),
                      _buildMetricItem('SENT', '${_dataUsageMb} MB',
                          const Color(0xFF9D00FF)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: MediaQuery.of(context).size.height * 0.32,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF050B14).withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildHudIconButton(
                    icon: _isTorchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    isActive: _isTorchOn,
                    color: Colors.amberAccent,
                    onTap: () =>
                        setState(() => _isTorchOn = !_isTorchOn),
                  ),
                  const SizedBox(height: 12),
                  _buildHudIconButton(
                    icon: Icons.flip_camera_android_rounded,
                    isActive: false,
                    color: const Color(0xFF00F5FF),
                    onTap: () => setState(
                        () => _isFrontCamera = !_isFrontCamera),
                  ),
                  const SizedBox(height: 12),
                  _buildHudIconButton(
                    icon: _isAFLocked
                        ? Icons.filter_center_focus
                        : Icons.center_focus_weak,
                    isActive: _isAFLocked,
                    color: const Color(0xFF00FF88),
                    onTap: () =>
                        setState(() => _isAFLocked = !_isAFLocked),
                  ),
                  const SizedBox(height: 12),
                  _buildHudIconButton(
                    icon: _isLandscapeLocked
                        ? Icons.screen_lock_landscape
                        : Icons.screen_rotation,
                    isActive: _isLandscapeLocked,
                    color: const Color(0xFF9D00FF),
                    onTap: () => setState(() =>
                        _isLandscapeLocked = !_isLandscapeLocked),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: MediaQuery.of(context).size.height * 0.28,
            bottom: MediaQuery.of(context).size.height * 0.28,
            child: Container(
              width: 38,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF050B14).withOpacity(0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Text('ZOOM',
                      style: TextStyle(
                          fontSize: 8,
                          fontFamily: 'Courier',
                          color: Colors.white54,
                          letterSpacing: 1.2)),
                  Text('${_zoomLevel.toStringAsFixed(1)}x',
                      style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'Courier',
                          color: Color(0xFF00F5FF),
                          fontWeight: FontWeight.bold)),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          activeTrackColor: const Color(0xFF00F5FF),
                          inactiveTrackColor: Colors.white12,
                          thumbColor: const Color(0xFF00F5FF),
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6),
                          overlayColor:
                              const Color(0xFF00F5FF).withOpacity(0.2),
                        ),
                        child: Slider(
                          value: _zoomLevel,
                          min: 1.0,
                          max: 5.0,
                          onChanged: (v) =>
                              setState(() => _zoomLevel = v),
                        ),
                      ),
                    ),
                  ),
                  const Icon(Icons.search, size: 12, color: Colors.white54),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF080D1A).withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFF00F5FF).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _showQualityModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D31),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFF00F5FF).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hd_outlined,
                              color: Color(0xFF00F5FF), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _resolution,
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down,
                              color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      color: _isMuted
                          ? Colors.redAccent
                          : const Color(0xFF00F5FF),
                    ),
                    onPressed: () =>
                        setState(() => _isMuted = !_isMuted),
                    style: IconButton.styleFrom(
                      backgroundColor: _isMuted
                          ? Colors.red.withOpacity(0.15)
                          : const Color(0xFF131D31),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() => _isStreaming = !_isStreaming);
                    },
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isStreaming
                              ? [
                                  const Color(0xFFFF2A6D),
                                  const Color(0xFF9D00FF)
                                ]
                              : [
                                  const Color(0xFF00F5FF),
                                  const Color(0xFF0088FF)
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isStreaming
                                    ? const Color(0xFFFF2A6D)
                                    : const Color(0xFF00F5FF))
                                .withOpacity(0.45),
                            blurRadius: 18,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Icon(
                        _isStreaming
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D31),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('PC HOST',
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.white54,
                                fontFamily: 'Courier')),
                        Text('192.168.1.150:8276',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF00F5FF),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Courier')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontFamily: 'Courier',
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Courier',
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 18,
      color: Colors.white12,
    );
  }

  Widget _buildHudIconButton({
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isActive ? color : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? color : Colors.white70,
        ),
      ),
    );
  }
}

class GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00F5FF).withOpacity(0.04)
      ..strokeWidth = 0.8;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HudReticlePainter extends CustomPainter {
  final double angle;
  final bool isLocked;

  HudReticlePainter({required this.angle, required this.isLocked});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final primaryColor =
        isLocked ? const Color(0xFF00F5FF) : Colors.amberAccent;

    final paintArc = Paint()
      ..color = primaryColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paintAccent = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final bPaint = Paint()
      ..color = primaryColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const bracketLen = 22.0;
    const pad = 12.0;

    canvas.drawLine(const Offset(pad, pad + bracketLen),
        const Offset(pad, pad), bPaint);
    canvas.drawLine(const Offset(pad, pad),
        const Offset(pad + bracketLen, pad), bPaint);

    canvas.drawLine(Offset(size.width - pad - bracketLen, pad),
        Offset(size.width - pad, pad), bPaint);
    canvas.drawLine(Offset(size.width - pad, pad),
        Offset(size.width - pad, pad + bracketLen), bPaint);

    canvas.drawLine(Offset(pad, size.height - pad - bracketLen),
        Offset(pad, size.height - pad), bPaint);
    canvas.drawLine(Offset(pad, size.height - pad),
        Offset(pad + bracketLen, size.height - pad), bPaint);

    canvas.drawLine(
        Offset(size.width - pad - bracketLen, size.height - pad),
        Offset(size.width - pad, size.height - pad),
        bPaint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad - bracketLen),
        Offset(size.width - pad, size.height - pad), bPaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 46),
      0,
      math.pi / 2,
      false,
      paintAccent,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 46),
      math.pi,
      math.pi / 2,
      false,
      paintAccent,
    );

    canvas.drawCircle(Offset.zero, 60, paintArc);
    canvas.restore();

    final dotPaint = Paint()..color = primaryColor;
    canvas.drawCircle(center, 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant HudReticlePainter oldDelegate) =>
      oldDelegate.angle != angle || oldDelegate.isLocked != isLocked;
}
