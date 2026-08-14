// lib/screens/info_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/banner_ad_widget.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text('Infos & À propos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Logo TDG
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1565C0), width: 3),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/tdg_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: kNavy,
                              child: Center(
                                child: Text(
                                  'TDG',
                                  style: TextStyle(
                                    color: kGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'TAYSIR DIGITAL GROUP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B3A6B),
                        ),
                      ),
                      Text(
                        '« ${AppConstants.appSlogan} »',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1565C0),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // À propos de l'application
                _InfoCard(
                  headerIcon: Icons.phone_android,
                  headerIconColor: const Color(0xFF1565C0),
                  headerIconBg: const Color(0xFFE8F0FF),
                  title: 'À propos de l\'application',
                  child: Column(
                    children: const [
                      _InfoRow(label: 'Application', value: AppConstants.appName),
                      _InfoRow(label: 'Version', value: AppConstants.appVersion),
                      _InfoRow(label: 'Framework', value: 'Flutter 3'),
                      _InfoRow(label: 'Plateforme', value: 'Android 7+ (API 24+)'),
                      _InfoRow(label: 'NDK', value: 'r26d'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Développeur
                _InfoCard(
                  headerIcon: Icons.person_outline,
                  headerIconColor: const Color(0xFF2E7D32),
                  headerIconBg: const Color(0xFFEAF3DE),
                  title: 'Développeur',
                  child: Column(
                    children: const [
                      _InfoRow(label: 'Nom', value: AppConstants.appDeveloper),
                      _InfoRow(label: 'Titre', value: 'PDG / CEO'),
                      _InfoRow(label: 'Société', value: AppConstants.appCompany),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Contacts
                _InfoCard(
                  headerIcon: Icons.phone_in_talk_outlined,
                  headerIconColor: const Color(0xFF6A1B9A),
                  headerIconBg: const Color(0xFFF3E8FF),
                  title: 'Contacts',
                  child: Column(
                    children: [
                      _ContactRow(
                        icon: Icons.phone,
                        iconColor: const Color(0xFF2E7D32),
                        label: AppConstants.contactPhone1,
                        onTap: () => _launch('tel:${AppConstants.contactPhone1Raw}'),
                      ),
                      _ContactRow(
                        icon: Icons.email_outlined,
                        iconColor: const Color(0xFFD32F2F),
                        label: AppConstants.contactEmail,
                        onTap: () =>
                            _launch('mailto:${AppConstants.contactEmail}'),
                      ),
                      _ContactRow(
                        icon: Icons.language,
                        iconColor: const Color(0xFF1565C0),
                        label: 'Site web TDG',
                        onTap: () => _launch('https://taysirdigitalgroup.com'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Nous soutenir
                _InfoCard(
                  headerIcon: Icons.favorite_outline,
                  headerIconColor: const Color(0xFFE91E63),
                  headerIconBg: const Color(0xFFFCE4EC),
                  title: 'Nous soutenir',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Aidez-nous à continuer ce travail de diffusion du savoir islamique',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                      // PayPal
                      _DonateButton(
                        icon: Icons.payment,
                        iconColor: const Color(0xFF003087),
                        bgColor: const Color(0xFFE8F0FF),
                        borderColor: const Color(0xFFBBD4FF),
                        label: 'PayPal',
                        sublabel: 'paypal.me/MBENGUE28',
                        onTap: () => _launch(AppConstants.paypalUrl),
                      ),
                      const SizedBox(height: 8),

                      // Wave lien marchand
                      _DonateButton(
                        icon: Icons.waves,
                        iconColor: const Color(0xFF1BC5BD),
                        bgColor: const Color(0xFFE0FAF9),
                        borderColor: const Color(0xFFB2EBF2),
                        label: 'Wave',
                        sublabel: 'pay.wave.com · Taysir Digital Group',
                        onTap: () => _launch(AppConstants.waveUrl),
                      ),
                      const SizedBox(height: 4),

                      // Numéros copiables
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            _CopyNumRow(
                              label: 'Wave',
                              number: AppConstants.contactPhone1,
                              rawNumber: AppConstants.contactPhone1Raw,
                              copyColor: const Color(0xFF1BC5BD),
                            ),
                            Divider(color: Colors.grey.shade100, height: 1),
                            _CopyNumRow(
                              label: 'Orange Money',
                              number: AppConstants.contactPhone2,
                              rawNumber: AppConstants.contactPhone2Raw,
                              copyColor: const Color(0xFFFF6600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Copyright
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.copyright, size: 18, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text(
                        '© 2026 Taysir Digital Group (TDG)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tous droits réservés',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  void _launch(String url) async {
    // url_launcher peut être ajouté ; ici stub pour ne pas alourdir les dépendances
    debugPrint('Launch: $url');
  }
}

// ── Composants réutilisables ─────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData headerIcon;
  final Color headerIconColor;
  final Color headerIconBg;
  final String title;
  final Widget child;

  const _InfoCard({
    required this.headerIcon,
    required this.headerIconColor,
    required this.headerIconBg,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: headerIconBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(headerIcon, size: 15, color: headerIconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _ContactRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _DonateButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _DonateButton({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _CopyNumRow extends StatelessWidget {
  final String label;
  final String number;
  final String rawNumber;
  final Color copyColor;

  const _CopyNumRow({
    required this.label,
    required this.number,
    required this.rawNumber,
    required this.copyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label : $number',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rawNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Numéro $label copié !'),
                  backgroundColor: copyColor,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Icon(Icons.copy, size: 13, color: copyColor),
            label: Text(
              'Copier',
              style: TextStyle(fontSize: 11, color: copyColor),
            ),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
