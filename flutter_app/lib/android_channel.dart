import 'package:flutter/services.dart';

/// Shared with `main.dart` (VPN lifecycle) and `tabs/split_tab.dart`
/// (installed-app picker) - same native channel, different methods.
const androidVpnChannel = MethodChannel('com.charonvpn.flutter_app/vpn');
