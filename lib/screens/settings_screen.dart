import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_settings.dart';
import '../models/stt_settings.dart';
import '../utils/audio_preferences.dart';
import '../utils/stt_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AudioSettings _settings = AudioSettings.defaults;
  SttSettings _sttSettings = SttSettings.defaults;
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _drivingMode = false;
  static const String _drivingModeKey = 'driving_mode_enabled';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await AudioPreferences.loadSettings();
    final sttSettings = await SttPreferences.loadSettings();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _settings = settings;
      _sttSettings = sttSettings;
      _drivingMode = prefs.getBool(_drivingModeKey) ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleDrivingMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_drivingModeKey, value);
    setState(() => _drivingMode = value);
  }

  Future<void> _saveSettings() async {
    await AudioPreferences.saveSettings(_settings);
    await SttPreferences.saveSettings(_sttSettings);
    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres sauvegardés !')),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser'),
        content:
            const Text('Réinitialiser tous les paramètres par défaut ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AudioPreferences.resetToDefaults();
      await SttPreferences.resetToDefaults();
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres réinitialisés !')),
        );
      }
    }
  }

  void _updateSettings(AudioSettings newSettings) {
    setState(() {
      _settings = newSettings;
      _hasChanges = true;
    });
  }

  void _updateSttSettings(SttSettings newSettings) {
    setState(() {
      _sttSettings = newSettings;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paramètres')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Sauvegarder',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Mode Conduite
          _buildSectionHeader('🚗 Mode Conduite'),
          SwitchListTile(
            key: const Key('driving_mode_toggle'),
            title: const Text('Mode conduite'),
            subtitle: const Text('Le quiz démarre toujours en mode mains-libres'),
            value: _drivingMode,
            onChanged: _toggleDrivingMode,
          ),
          const Divider(height: 32),

          // Section Reconnaissance vocale
          _buildSectionHeader('🎙️ Reconnaissance vocale'),
          _buildIntSlider(
            label: 'Patience silence',
            value: _sttSettings.pauseForSeconds,
            min: 2,
            max: 10,
            suffix: 's',
            subtitle: 'Temps d\'attente pendant le silence avant d\'arrêter',
            onChanged: (v) => _updateSttSettings(
              _sttSettings.copyWith(pauseForSeconds: v),
            ),
          ),
          const SizedBox(height: 16),
          _buildIntSlider(
            label: 'Durée max d\'écoute',
            value: _sttSettings.listenForSeconds,
            min: 5,
            max: 30,
            suffix: 's',
            subtitle: 'Durée totale maximale d\'enregistrement',
            onChanged: (v) => _updateSttSettings(
              _sttSettings.copyWith(listenForSeconds: v),
            ),
          ),
          const SizedBox(height: 16),
          _buildPercentSlider(
            label: 'Tolérance de réponse',
            value: _sttSettings.answerTolerance,
            min: 0.50,
            max: 1.00,
            subtitle: 'Seuil de similarité pour accepter une réponse',
            onChanged: (v) => _updateSttSettings(
              _sttSettings.copyWith(answerTolerance: v),
            ),
          ),
          const SizedBox(height: 16),
          _buildStepperRow(
            label: 'Tentatives max',
            value: _sttSettings.maxRetryAttempts,
            min: 1,
            max: 5,
            subtitle: 'Essais avant de passer au mot suivant (mains-libres)',
            onChanged: (v) => _updateSttSettings(
              _sttSettings.copyWith(maxRetryAttempts: v),
            ),
          ),
          const Divider(height: 32),

          // Section Audio
          _buildSectionHeader('🔊 Paramètres Audio'),
          _buildVoiceSelector(
            'Voix Français',
            _settings.frenchVoiceId,
            'fr',
            (voiceId) =>
                _updateSettings(_settings.copyWith(frenchVoiceId: voiceId)),
          ),
          const SizedBox(height: 16),

          _buildVoiceSelector(
            'Voix Coréen',
            _settings.koreanVoiceId,
            'ko',
            (voiceId) =>
                _updateSettings(_settings.copyWith(koreanVoiceId: voiceId)),
          ),
          const SizedBox(height: 16),

          _buildVoiceSelector(
            'Voix Anglais',
            _settings.englishVoiceId,
            'en',
            (voiceId) =>
                _updateSettings(_settings.copyWith(englishVoiceId: voiceId)),
          ),

          const Divider(height: 32),

          _buildSectionHeader('🎛️ Qualité Audio'),
          _buildSlider(
            'Stabilité',
            _settings.stability,
            'Plus stable et prévisible',
            'Plus expressif et varié',
            (value) => _updateSettings(_settings.copyWith(stability: value)),
          ),
          const SizedBox(height: 16),

          _buildSlider(
            'Similarité',
            _settings.similarityBoost,
            'Plus proche de la voix originale',
            'Plus de liberté créative',
            (value) =>
                _updateSettings(_settings.copyWith(similarityBoost: value)),
          ),

          const Divider(height: 32),

          // Actions
          FilledButton.icon(
            onPressed: _hasChanges ? _saveSettings : null,
            icon: const Icon(Icons.save),
            label: const Text('Sauvegarder les modifications'),
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Réinitialiser par défaut'),
          ),

          const SizedBox(height: 32),

          // Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Information',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ces paramètres s\'appliqueront uniquement aux NOUVEAUX mots ajoutés. '
                    'Pour mettre à jour les mots existants, utilisez le bouton '
                    '"Régénérer audio" dans la liste de mots.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildVoiceSelector(
    String label,
    String currentVoiceId,
    String langCode,
    Function(String) onChanged,
  ) {
    final currentVoiceName =
        ElevenLabsVoices.getNameFromId(currentVoiceId) ?? 'Unknown';
    final recommended = ElevenLabsVoices.recommendedByLanguage[langCode] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: currentVoiceId,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
            helperText: 'Voix actuelle: $currentVoiceName',
          ),
          items: ElevenLabsVoices.voices.entries.map((entry) {
            final isRecommended = recommended.contains(entry.key);
            return DropdownMenuItem(
              value: entry.value,
              child: Row(
                children: [
                  Text(entry.key),
                  if (isRecommended) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Recommandé',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    String maxLabel,
    String minLabel,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              value.toStringAsFixed(2),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                minLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: Text(
                maxLabel,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required String suffix,
    required String subtitle,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text('$value$suffix',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              )),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value$suffix',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  Widget _buildPercentSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String subtitle,
    required Function(double) onChanged,
  }) {
    final percent = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text('$percent%',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              )),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 100).round(),
          label: '$percent%',
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildStepperRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required String subtitle,
    required Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            Text('$value',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              )),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}
