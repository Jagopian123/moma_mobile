import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

const _shellPaths = {'/home', '/transaction', '/asset', '/settings'};

class NotificationNavigator {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static GoRouter? _router;
  static String? _pendingPath;

  // Stream untuk trigger navigasi dari HomePage saat sudah di home
  // (initState tidak re-fire kalau widget instance sama)
  static final _routeController = StreamController<String>.broadcast();
  static Stream<String> get onRouteRequired => _routeController.stream;

  static void attach(GoRouter router) => _router = router;

  static void handleRoute(String? route) {
    if (route != null && route.startsWith('url:')) {
      launchUrl(Uri.parse(route.substring(4)), mode: LaunchMode.externalApplication);
      return;
    }
    final path = _toPath(route);

    if (_router == null) {
      _pendingPath = path;
      return;
    }

    Future.delayed(Duration.zero, () {
      if (_shellPaths.contains(path)) {
        _router?.go(path);
        return;
      }
      // go('/home') memastikan currentConfiguration bersih sebelum push,
      // dan mount HomePage jika belum ada sehingga navigatePending dipanggil
      _pendingPath = path;
      _routeController.add(path);
      _router?.go('/home');
    });
  }

  static void queueRoute(String? route) {
    if (route == null || route.isEmpty || route == 'home') return;
    if (route.startsWith('url:')) {
      launchUrl(Uri.parse(route.substring(4)), mode: LaunchMode.externalApplication);
      return;
    }
    _pendingPath = _toPath(route);
  }

  static void navigatePending(BuildContext context) {
    final path = _pendingPath;
    _pendingPath = null;
    if (path == null) return;
    if (_shellPaths.contains(path)) {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  static String _toPath(String? route) {
    switch (route) {
      case 'budget':            return '/budget';
      case 'subscription':      return '/subscription';
      case 'debt':              return '/debt';
      case 'premium':           return '/premium';
      case 'transaction':       return '/transaction';
      case 'insights':          return '/insights';
      case 'notifications':     return '/notifications';
      case 'settings':          return '/settings';
      case 'asset':             return '/asset';
      case 'financial-plan':    return '/financial-plan';
      case 'ai-chat':           return '/ai-chat';
      case 'ai-insight':        return '/ai-insight';
      case 'profile':           return '/profile';
      case 'manage-categories': return '/manage-categories';
      case 'misi':              return '/misi';
      default:                  return '/home';
    }
  }
}
