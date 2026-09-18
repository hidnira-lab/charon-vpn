/// Combined tunnel state, derived in `main.dart` from
/// `_xrayRunning`/`_tunnelRunning`/`_blocked`/`_reconnecting`. Shared between
/// `DashboardTab` and `ConnectDock` (Milestone 13) so both surfaces agree on
/// what "connected" means.
enum ConnState { connected, connecting, reconnecting, disconnected }
