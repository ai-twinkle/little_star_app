import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:little_star_app/data/services/app_info_service.dart';
import 'package:little_star_app/ui/about/widgets/info_section.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final AppInfoService _appInfoService = AppInfoService();

  String _version = 'Loading...';
  String _buildNumber = '';
  String _llamaCppVersion = 'Loading...';
  Map<String, String> _deviceInfo = {};
  Map<String, String> _storageInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final version = await _appInfoService.getAppVersion();
      final buildNumber = await _appInfoService.getBuildNumber();
      final llamaVersion = await _appInfoService.getLlamaCppVersion();
      final deviceInfo = await _appInfoService.getDeviceInfo();
      final storageInfo = await _appInfoService.getStorageInfo();

      if (mounted) {
        setState(() {
          _version = version;
          _buildNumber = buildNumber;
          _llamaCppVersion = llamaVersion;
          _deviceInfo = deviceInfo;
          _storageInfo = storageInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = 'Unknown';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openLicenses() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Theme(
          data: Theme.of(context),
          child: const LicensePage(
            applicationName: 'Little Star App',
            applicationVersion: '0.0.3',
            applicationLegalese: '© 2025 Twinkle AI',
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法開啟連結: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('關於'),
        backgroundColor: theme.colorScheme.primaryContainer,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // App Icon and Name
                  _buildAppHeader(theme),

                  const SizedBox(height: 32),

                  // Description Card
                  _buildDescriptionCard(theme),

                  const SizedBox(height: 24),

                  // Version Information Section
                  InfoSection(
                    title: '版本資訊',
                    children: [
                      _buildInfoTile(
                        icon: Icons.info_outline,
                        title: '應用版本',
                        subtitle: _buildNumber.isNotEmpty
                            ? '$_version ($_buildNumber)'
                            : _version,
                      ),
                      _buildInfoTile(
                        icon: Icons.memory,
                        title: 'llama.cpp 版本',
                        subtitle: _llamaCppVersion,
                      ),
                      _buildInfoTile(
                        icon: Icons.phone_android,
                        title: '平台',
                        subtitle: _getPlatformName(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Device Information Section (Phase 2)
                  if (_deviceInfo.isNotEmpty && kDebugMode) ...[
                    InfoSection(
                      title: '裝置資訊',
                      children: _deviceInfo.entries.map((entry) {
                        return _buildInfoTile(
                          icon: Icons.smartphone,
                          title: _formatKey(entry.key),
                          subtitle: entry.value,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Storage Information Section (Phase 2)
                  if (_storageInfo.isNotEmpty && kDebugMode) ...[
                    InfoSection(
                      title: '儲存路徑',
                      children: _storageInfo.entries.map((entry) {
                        return _buildInfoTile(
                          icon: Icons.folder,
                          title: entry.key,
                          subtitle: entry.value,
                          isMonospace: true,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Links Section
                  InfoSection(
                    title: '相關連結',
                    children: [
                      _buildLinkTile(
                        icon: Icons.description,
                        title: '開源授權',
                        subtitle: '查看使用的開源套件',
                        onTap: _openLicenses,
                      ),
                      _buildLinkTile(
                        icon: Icons.code,
                        title: 'GitHub 儲存庫',
                        subtitle: 'github.com/Twinke-AI/little_star_app',
                        onTap: () => _openUrl('https://github.com/Twinke-AI/little_star_app'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  _buildFooter(theme),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildAppHeader(ThemeData theme) {
    return Column(
      children: [
        // App Icon
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome,
            size: 48,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // App Name
        Text(
          'Little Star App',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Version
        Text(
          '版本 $_version',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'A Twinkle AI\'s little star project.\n\n'
            '本應用使用 llama.cpp 在本地運行大型語言模型,保護您的隱私。',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isMonospace = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: isMonospace
            ? const TextStyle(fontFamily: 'monospace', fontSize: 12)
            : null,
      ),
      dense: true,
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.favorite,
          color: Colors.red[300],
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          '© 2025 Twinkle AI',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'DEBUG MODE',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange[900],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _getPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  String _formatKey(String key) {
    // Convert camelCase to Title Case with spaces
    return key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim();
  }
}
