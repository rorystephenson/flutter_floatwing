import 'dart:ffi';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_floatwing/flutter_floatwing.dart';

// typedef TransitionBuilder = Widget Function(BuildContext context, Widget? child);
// typedef WidgetBuilder = Widget Function(BuildContext context);

class FloatwingProvider extends InheritedWidget {
  final Window? window;

  FloatwingProvider(Widget child, {
    Key? key,
    required this.window,
  }) : super(key: key, child: child);

  @override
  bool updateShouldNotify(FloatwingProvider oldWidget) {
    return true;
  }

  static T? of<T>(BuildContext context) {
    return null;
  }
}

class FloatwingContainer extends StatefulWidget {

  final Widget? child;
  final WidgetBuilder? builder;

  const FloatwingContainer({
    Key? key,
    this.child,
    this.builder,
  }) : assert(child != null || builder != null),
    super(key: key);

  @override
  State<FloatwingContainer> createState() => _FloatwingContainerState();
}

class _FloatwingContainerState extends State<FloatwingContainer> {

  var _key = GlobalKey();

  Window? _window = FloatwingPlugin().currentWindow;

  var _ignorePointer = false;
  var _autosize = true;

  @override
  void initState() {
    super.initState();
    initSyncState();

    // SchedulerBinding.instance?.addPostFrameCallback((_) {});
  }

  initSyncState() async {
    if (_window == null) {
      print("[provider] don't sync window at init, need to do at here");
      await FloatwingPlugin().ensureWindow().then((w) {
        _window = w;
        print("[window-normal] register event listener ===> $_window $w");
      });
    }
    // init window from engine and save, only call this int here
    // sync a window from engine
    print("[provider] sync finish, so trigger to rebuild");
    print("[provider] window: $_window ${FloatwingPlugin().currentWindow}");
    _updateFromWindow();
    _window?.on("resumed", (w, _) => _updateFromWindow());
  }

  _updateFromWindow() {
    // clickable == !ignorePointer
    _ignorePointer = !(_window?.config?.clickable ?? true);
    _autosize = _window?.config?.autosize ?? true;

    print("[provider] the view to ignore pointer: $_ignorePointer");

    // update the flutter ui
    setState((){});
  }

  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance?.addPostFrameCallback(_onPostFrame);
    return Material(
      color: Colors.transparent,
      child: UnconstrainedBox(
        child: FloatwingProvider(
          Container(
            key: _key,
            // decoration: BoxDecoration(
            //   border: Border.all(color: Colors.blueAccent)
            // ),
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (n) {
                print("=======> size changed");
                SchedulerBinding.instance?.addPostFrameCallback(_onPostFrame);
                return true;
              },
              child: SizeChangedLayoutNotifier(
                child: widget.builder != null
                  ? Builder(builder: widget.builder!)
                  : widget.child!,
              ),
            )
          ).ignorePointer(ignoring: _ignorePointer),
          window: _window,
        ),
      ),
    );
  }

  var _oldSize;

  void _onPostFrame(_) {
    if (!_autosize) return;

    var size = _key.currentContext?.size;

    print("[provider] autosize enable, on size change: $size");

    if (size == null || _window == null) {
      _oldSize = size;
      return;
    }

    _oldSize = size;
    print("old: $_oldSize, new: $size");
    
    // take pixelRadio from window
    var _pixelRadio = _window?.pixelRadio ?? 1;

    _window?.update(WindowConfig(
      width: (size.width * _pixelRadio).toInt(),
      height: (size.height * _pixelRadio).toInt(),
    )).then((w) {
      // window object hasbee update
      print("[provider] update window size: $w $_window");
    });
  }
}

extension IgnorePointerExtension on Widget {
  Widget ignorePointer({ bool ignoring = false }) {
    return IgnorePointer(child: this, ignoring: ignoring);
  }
}

extension WidgetProviderExtension on Widget {
  Widget floatwing({
    bool ignorePointer = false,
  }) {
    return FloatwingContainer(
      child: this, 
    );
  }
}

extension WidgetBuilderProviderExtension on WidgetBuilder {
  WidgetBuilder floatwing({
    bool ignorePointer = false,
  }) {
    return (_) => FloatwingContainer(
      builder: this, 
    );
  }

  Widget make() {
    return Builder(builder: this);
  }
}