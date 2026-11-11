import 'package:flutter/material.dart';

import 'common.dart';

/// Runs [load] and shows loading, error-with-retry, or the built content.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Loading();
        if (snap.hasError) return ErrorBox(error: snap.error!, onRetry: _reload);
        return widget.builder(context, snap.data as T, _reload);
      },
    );
  }
}
