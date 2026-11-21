import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(CardPageRoute<T>(builder: (_) => page));
}

Future<T?> openDialog<T>(BuildContext context, Widget child) =>
    showFloatingDialog<T>(context: context, child: child);
