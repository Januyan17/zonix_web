import 'package:flutter/material.dart';

/// Keeps a tab's state (scroll position, half-typed fields) alive while
/// another tab is showing.
class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
