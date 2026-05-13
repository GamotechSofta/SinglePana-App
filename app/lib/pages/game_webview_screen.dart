import 'dart:async';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/api_config.dart';
import '../services/session_coordinator.dart';

class GameWebViewScreen extends StatefulWidget {
  const GameWebViewScreen({
    required this.launchUrl,
    required this.title,
    super.key,
  });

  final String launchUrl;
  final String title;

  @override
  State<GameWebViewScreen> createState() => _GameWebViewScreenState();
}

class _GameWebViewScreenState extends State<GameWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  int _progress = 0;
  String _error = '';
  Uri? _launchUri;

  @override
  void initState() {
    super.initState();
    _launchUri = Uri.tryParse(widget.launchUrl);

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress;
              _loading = progress < 100;
            });
          },
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = '';
            });
            final uri = Uri.tryParse(url);
            unawaited(_handleSessionExpiryNavigation(uri));
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _progress = 100;
            });
            final uri = Uri.tryParse(url);
            unawaited(_handleSessionExpiryNavigation(uri));
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            // Sub-resource failures (analytics, ads, extra scripts) are common in
            // vendor games like Aviator — do not block the whole game for those.
            if (error.isForMainFrame != true) return;

            if (error.errorType == WebResourceErrorType.authentication ||
                error.errorType == WebResourceErrorType.proxyAuthentication) {
              unawaited(SessionCoordinator.instance.forceLogoutToLogin(
                message: 'Your session expired. Please log in again.',
              ));
              return;
            }

            setState(() {
              _loading = false;
              _error =
                  error.description.isNotEmpty ? error.description : 'Load error (${error.errorCode})';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (_shouldForceAppLogin(uri)) {
              unawaited(SessionCoordinator.instance.forceLogoutToLogin(
                message: 'Your session expired. Please log in again.',
              ));
              return NavigationDecision.prevent;
            }

            final scheme = uri?.scheme.toLowerCase() ?? '';
            if (scheme == 'http' ||
                scheme == 'https' ||
                scheme == 'about' ||
                scheme == 'blob' ||
                scheme == 'data') {
              return NavigationDecision.navigate;
            }
            // Some SPAs use javascript: URLs during bootstrap.
            if (scheme == 'javascript') return NavigationDecision.navigate;

            return NavigationDecision.prevent;
          },
        ),
      );

    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      unawaited(platformController.setMixedContentMode(MixedContentMode.alwaysAllow));
      unawaited(platformController.setMediaPlaybackRequiresUserGesture(false));
    }

    unawaited(_controller.loadRequest(Uri.parse(widget.launchUrl)));
  }

  /// Game providers often redirect / deep-link using query fragments when session ends.
  bool _shouldForceAppLogin(Uri? uri) {
    if (uri == null) return false;

    try {
      final apiHost = Uri.parse(kApiBaseUrl).host.toLowerCase();
      if (apiHost.isNotEmpty && uri.host.toLowerCase() == apiHost) {
        final p = uri.path.toLowerCase();
        if (p.contains('/login') || p.contains('/auth/login') || p.contains('/sessions')) {
          return true;
        }
      }
    } catch (_) {}

    final haystack = uri.toString().toLowerCase();
    const hints = [
      'session_expired',
      'session-expired',
      'sessiontimeout',
      'session_timeout',
      'token_expired',
      'token-expired',
      'login_required',
      'authentication_failed',
      'auth_failed',
      'unauthorized_access',
      'error=401',
      'code=401',
      'status=401',
    ];
    for (final h in hints) {
      if (haystack.contains(h)) return true;
    }

    final origin = '${uri.scheme}://${uri.host}'.toLowerCase();
    final launchOrigin =
        '${_launchUri?.scheme ?? ''}://${_launchUri?.host ?? ''}'.toLowerCase();
    if (_launchUri != null && origin == launchOrigin) {
      final p = uri.path.toLowerCase();
      if ((p.endsWith('/login') || p.contains('/logout')) && !_launchSamePath(uri.path)) {
        return true;
      }
    }

    return false;
  }

  bool _launchSamePath(String path) {
    final launchPath = _launchUri?.path ?? '';
    return path == launchPath;
  }

  Future<void> _handleSessionExpiryNavigation(Uri? uri) async {
    if (!mounted || uri == null) return;
    if (!_shouldForceAppLogin(uri)) return;
    await SessionCoordinator.instance.forceLogoutToLogin(
      message: 'Your session expired. Please log in again.',
    );
  }

  Future<void> _onPullRefresh() async {
    setState(() {
      _error = '';
      _loading = true;
    });
    await _controller.reload();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: () {
                setState(() {
                  _error = '';
                  _loading = true;
                });
                unawaited(_controller.reload());
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Stack(
          children: [
            EasyRefresh(
              header: const ClassicHeader(triggerOffset: 70, clamping: false),
              onRefresh: _onPullRefresh,
              child: WebViewWidget(controller: _controller),
            ),
            if (_loading)
              LinearProgressIndicator(
                value: _progress > 0 && _progress < 100 ? _progress / 100 : null,
                minHeight: 2,
              ),
            if (_error.isNotEmpty)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Unable to load game',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _error = '';
                                _loading = true;
                              });
                              unawaited(_controller.reload());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
