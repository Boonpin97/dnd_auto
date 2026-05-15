import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(MobileAds.instance.initialize());
  runApp(const AutoDndApp());
}

class AutoDndApp extends StatelessWidget {
  const AutoDndApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);
    return MaterialApp(
      title: 'Auto DND',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NativeBridge _bridge = NativeBridge();
  Timer? _refreshTimer;
  BannerAd? _bannerAd;
  AppStatus? _status;
  bool _bannerLoaded = false;
  bool _loadingBanner = false;
  bool _loading = true;
  bool _changingService = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatus());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadBannerAd());
    });
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_loadStatus(silent: true)),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBannerAd() async {
    if (_loadingBanner || _bannerAd != null || !mounted) {
      return;
    }

    _loadingBanner = true;
    final width = MediaQuery.sizeOf(context).width.truncate();
    final adaptiveSize = width > 0
        ? await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width)
        : null;
    final adSize = adaptiveSize ?? AdSize.banner;
    final banner = BannerAd(
      size: adSize,
      adUnitId: AdConfig.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _bannerAd = null;
            _bannerLoaded = false;
          });
        },
      ),
    );

    _bannerAd = banner;
    _loadingBanner = false;
    unawaited(banner.load());
  }

  Future<void> _loadStatus({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final status = await _bridge.getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _openPicker() async {
    final status = _status;
    if (status == null) {
      return;
    }

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(
          bridge: _bridge,
          initiallySelected: status.selectedApps
              .map((app) => app.packageName)
              .toSet(),
        ),
      ),
    );

    if (updated == true) {
      await _loadStatus();
    }
  }

  Future<void> _toggleService(bool enabled) async {
    setState(() {
      _changingService = true;
    });

    try {
      if (enabled) {
        await _bridge.startMonitoring();
      } else {
        await _bridge.stopMonitoring();
      }
      await _loadStatus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update service: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingService = false;
        });
      }
    }
  }

  Future<void> _removeApp(InstalledApp app) async {
    await _bridge.removeSelectedApp(app.packageName);
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Auto DND')),
      bottomNavigationBar: _bannerAd != null && _bannerLoaded
          ? SafeArea(
              top: false,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
      body: _loading && _status == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: theme.textTheme.bodyLarge),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStatus,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PermissionCard(
                    status: _status!,
                    bridge: _bridge,
                    onChanged: _loadStatus,
                  ),
                  const SizedBox(height: 16),
                  StatusCard(status: _status!),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Monitoring service',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              Switch(
                                value: _status!.serviceEnabled,
                                onChanged: _changingService
                                    ? null
                                    : _toggleService,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _status!.serviceEnabled
                                ? 'Foreground monitoring is active. DND will enable automatically while media audio stays allowed.'
                                : 'Monitoring is stopped.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Trigger apps',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _openPicker,
                                icon: const Icon(Icons.add),
                                label: const Text('Add app'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_status!.selectedApps.isEmpty)
                            const Text('No trigger apps selected.')
                          else
                            ..._status!.selectedApps.map(
                              (app) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SelectedAppTile(
                                  app: app,
                                  onRemove: () => _removeApp(app),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class PermissionCard extends StatelessWidget {
  const PermissionCard({
    super.key,
    required this.status,
    required this.bridge,
    required this.onChanged,
  });

  final AppStatus status;
  final NativeBridge bridge;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = <Widget>[
      if (!status.hasUsageAccess)
        PermissionAction(
          title: 'Usage access',
          description:
              'Required to detect the app currently in the foreground.',
          buttonText: 'Grant usage access',
          onPressed: () async {
            await bridge.openUsageAccessSettings();
            await onChanged();
          },
        ),
      if (!status.hasNotificationPolicyAccess)
        PermissionAction(
          title: 'Do Not Disturb access',
          description:
              'Required to enable and disable DND automatically while preserving media playback.',
          buttonText: 'Grant DND access',
          onPressed: () async {
            await bridge.openDndAccessSettings();
            await onChanged();
          },
        ),
    ];

    return Card(
      color: missing.isEmpty
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
          : theme.colorScheme.errorContainer.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              missing.isEmpty ? 'Permissions ready' : 'Permissions required',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              missing.isEmpty
                  ? 'Usage access and DND access are granted. Auto DND uses priority mode so media can keep playing.'
                  : 'Grant both permissions before starting the monitoring service.',
            ),
            const SizedBox(height: 12),
            ...missing,
            PermissionAction(
              title: 'Battery optimization',
              description:
                  'Recommended to reduce the chance Android stops the foreground service.',
              buttonText: 'Request exclusion',
              onPressed: () async {
                await bridge.openBatteryOptimizationSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PermissionAction extends StatelessWidget {
  const PermissionAction({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String buttonText;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(description),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.status});

  final AppStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = status.dndEnabled ? Colors.red : Colors.green;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current status', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: CircleAvatar(backgroundColor: statusColor),
                  label: Text(status.dndEnabled ? 'DND on' : 'DND off'),
                ),
                Chip(
                  label: Text(
                    status.serviceEnabled
                        ? 'Service enabled'
                        : 'Service disabled',
                  ),
                ),
                if (status.pausedReason != null &&
                    status.pausedReason!.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: Text(status.pausedReason!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Foreground app: ${status.foregroundAppName ?? 'Unknown'}'),
            const SizedBox(height: 4),
            Text('Package: ${status.foregroundPackageName ?? 'Unavailable'}'),
            if (status.dndEnabledByUs) ...[
              const SizedBox(height: 4),
              const Text(
                'Auto DND enabled priority mode. Media audio should continue playing.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SelectedAppTile extends StatelessWidget {
  const SelectedAppTile({super.key, required this.app, required this.onRemove});

  final InstalledApp app;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIcon(bytes: app.iconBytes),
      title: Text(app.appName),
      subtitle: Text(app.packageName),
      trailing: IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({
    super.key,
    required this.bridge,
    required this.initiallySelected,
  });

  final NativeBridge bridge;
  final Set<String> initiallySelected;

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<InstalledApp> _apps = const [];
  late Set<String> _selected;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelected};
    unawaited(_loadApps());
  }

  Future<void> _loadApps() async {
    final apps = await widget.bridge.getInstalledApps();
    if (!mounted) {
      return;
    }
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await widget.bridge.saveSelectedApps(_selected.toList());
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _apps.where((app) {
      final q = _query.toLowerCase();
      return app.appName.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose trigger apps'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SearchBar(
                    hintText: 'Search apps',
                    leading: const Icon(Icons.search),
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final app = filtered[index];
                      final selected = _selected.contains(app.packageName);
                      return CheckboxListTile(
                        value: selected,
                        secondary: AppIcon(bytes: app.iconBytes),
                        title: Text(app.appName),
                        subtitle: Text(app.packageName),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(app.packageName);
                            } else {
                              _selected.remove(app.packageName);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (bytes == null || bytes!.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.apps));
    }

    return CircleAvatar(backgroundImage: MemoryImage(bytes!));
  }
}

class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.appName,
    required this.iconBytes,
  });

  final String packageName;
  final String appName;
  final Uint8List? iconBytes;

  factory InstalledApp.fromMap(Map<Object?, Object?> map) {
    return InstalledApp(
      packageName: map['packageName']! as String,
      appName: map['appName']! as String,
      iconBytes: map['iconBytes'] as Uint8List?,
    );
  }
}

class AppStatus {
  const AppStatus({
    required this.hasUsageAccess,
    required this.hasNotificationPolicyAccess,
    required this.serviceEnabled,
    required this.dndEnabled,
    required this.dndEnabledByUs,
    required this.selectedApps,
    required this.foregroundPackageName,
    required this.foregroundAppName,
    required this.pausedReason,
  });

  final bool hasUsageAccess;
  final bool hasNotificationPolicyAccess;
  final bool serviceEnabled;
  final bool dndEnabled;
  final bool dndEnabledByUs;
  final List<InstalledApp> selectedApps;
  final String? foregroundPackageName;
  final String? foregroundAppName;
  final String? pausedReason;

  factory AppStatus.fromMap(Map<Object?, Object?> map) {
    return AppStatus(
      hasUsageAccess: map['hasUsageAccess'] as bool? ?? false,
      hasNotificationPolicyAccess:
          map['hasNotificationPolicyAccess'] as bool? ?? false,
      serviceEnabled: map['serviceEnabled'] as bool? ?? false,
      dndEnabled: map['dndEnabled'] as bool? ?? false,
      dndEnabledByUs: map['dndEnabledByUs'] as bool? ?? false,
      selectedApps: ((map['selectedApps'] as List<Object?>?) ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(InstalledApp.fromMap)
          .toList(),
      foregroundPackageName: map['foregroundPackageName'] as String?,
      foregroundAppName: map['foregroundAppName'] as String?,
      pausedReason: map['pausedReason'] as String?,
    );
  }
}

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('auto_dnd/methods');

  Future<AppStatus> getStatus() async {
    final map = await _channel.invokeMethod<Map<Object?, Object?>>('getStatus');
    return AppStatus.fromMap(map ?? const {});
  }

  Future<List<InstalledApp>> getInstalledApps() async {
    final list = await _channel.invokeListMethod<Object?>('getInstalledApps');
    return (list ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(InstalledApp.fromMap)
        .toList();
  }

  Future<void> saveSelectedApps(List<String> packages) {
    return _channel.invokeMethod('saveSelectedApps', <String, Object?>{
      'packages': packages,
    });
  }

  Future<void> removeSelectedApp(String packageName) {
    return _channel.invokeMethod('removeSelectedApp', <String, Object?>{
      'packageName': packageName,
    });
  }

  Future<void> startMonitoring() {
    return _channel.invokeMethod('startMonitoring');
  }

  Future<void> stopMonitoring() {
    return _channel.invokeMethod('stopMonitoring');
  }

  Future<void> openUsageAccessSettings() {
    return _channel.invokeMethod('openUsageAccessSettings');
  }

  Future<void> openDndAccessSettings() {
    return _channel.invokeMethod('openDndAccessSettings');
  }

  Future<void> openBatteryOptimizationSettings() {
    return _channel.invokeMethod('openBatteryOptimizationSettings');
  }
}

class AdConfig {
  // Google-provided Android test ad unit. Replace before publishing.
  static const bannerAdUnitId = 'ca-app-pub-3940256099942544/9214589741';
}
