import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class WebviewPage extends ConsumerWidget {
  const WebviewPage({
    required this.initialUrl,
  });

  static const String name = 'webview';

  final String initialUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(webViewProvider(initialUrl));
    final notifier = ref.watch(webViewProvider(initialUrl).notifier);

    return HarpyScaffold(
      safeArea: true,
      child: CustomScrollView(
        slivers: [
          HarpySliverAppBar(
            title: state.hasTitle
                ? Text(state.title!, overflow: TextOverflow.ellipsis)
                : null,
            fittedTitle: false,
            actions: [WebViewActions(notifier: notifier, state: state)],
          ),
          SliverFillRemaining(
            child: _WebView(
              state: state,
              notifier: notifier,
              initialUrl: initialUrl,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebView extends StatefulWidget {
  const _WebView({
    required this.state,
    required this.notifier,
    required this.initialUrl,
  });

  final WebViewState state;
  final WebViewStateNotifier notifier;
  final String initialUrl;

  @override
  State<_WebView> createState() => _WebViewState();
}

class _WebViewState extends State<_WebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    // Initialize platform-specific features
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: widget.notifier.onPageStarted,
          onPageFinished: widget.notifier.onPageFinished,
          onProgress: widget.notifier.onProgress,
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));

    // Platform specific setup
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    widget.notifier.onWebViewCreated(_controller);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        if (widget.state.canGoBack) {
          widget.notifier.goBack().ignore();
          return false;
        }
        return true;
      },
      child: Stack(
        alignment: AlignmentDirectional.topCenter,
        children: [
          const Center(child: CircularProgressIndicator()),
          WebViewWidget(
            controller: _controller,
            gestureRecognizers: const {Factory(EagerGestureRecognizer.new)},
          ),
          AnimatedSwitcher(
            duration: theme.animation.short,
            child: widget.state.loading
                ? LinearProgressIndicator(
                    value:
                        widget.state.loading ? widget.state.progress / 100 : 1,
                    backgroundColor: Colors.transparent,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
