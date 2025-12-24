import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Screen shown while waiting for the server to wake up from cold start.
/// Render's free tier sleeps after 15 minutes of inactivity and takes ~30s to wake.
class ServerWarmupScreen extends StatefulWidget {
  final Widget child;
  final String? serverUrl;

  const ServerWarmupScreen({
    super.key,
    required this.child,
    this.serverUrl,
  });

  @override
  State<ServerWarmupScreen> createState() => _ServerWarmupScreenState();
}

class _ServerWarmupScreenState extends State<ServerWarmupScreen>
    with SingleTickerProviderStateMixin {
  bool _isReady = false;
  bool _isError = false;
  String _statusMessage = 'Connecting to server...';
  int _retryCount = 0;
  static const int _maxRetries = 20; // ~60 seconds total (3s each)
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _checkServerHealth();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _baseUrl =>
      widget.serverUrl ??
      dotenv.env['MOVIEBOX_API_URL'] ??
      const String.fromEnvironment('MOVIEBOX_API_URL',
          defaultValue: 'http://192.168.1.7:8000');

  Future<void> _checkServerHealth() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    while (_retryCount < _maxRetries && !_isReady && mounted) {
      try {
        setState(() {
          if (_retryCount == 0) {
            _statusMessage = 'Connecting to server...';
          } else if (_retryCount < 5) {
            _statusMessage = 'Waking up server...';
          } else if (_retryCount < 10) {
            _statusMessage = 'Server is starting up...';
          } else {
            _statusMessage = 'Almost there...';
          }
        });

        final response = await dio.get('$_baseUrl/health');
        
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _isReady = true;
              _statusMessage = 'Connected!';
            });
          }
          return;
        }
      } catch (e) {
        _retryCount++;
        if (_retryCount >= _maxRetries) {
          if (mounted) {
            setState(() {
              _isError = true;
              _statusMessage = 'Could not connect to server';
            });
          }
          return;
        }
        // Wait before retry
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  void _retry() {
    setState(() {
      _isError = false;
      _retryCount = 0;
      _statusMessage = 'Connecting to server...';
    });
    _checkServerHealth();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo/icon
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isError
                            ? [Colors.red.shade700, Colors.red.shade900]
                            : [const Color(0xFFE50914), const Color(0xFFB20710)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (_isError ? Colors.red : const Color(0xFFE50914))
                              .withAlpha(102), // 0.4 * 255 = 102
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isError ? Icons.cloud_off : Icons.movie_filter,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 48),
            
            // Status message
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Progress indicator or retry button
            if (_isError) ...[
              const Text(
                'The server might be down.\nPlease check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFE50914),
                  ),
                  value: _retryCount / _maxRetries,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Render free tier servers sleep after inactivity.\nWaking up typically takes 30-60 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(128), // 0.5 * 255 = 128
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
