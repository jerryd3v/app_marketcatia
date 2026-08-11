import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/background_music_controller.dart';
import '../theme/app_colors.dart';

/// Controles del MusicPlayer en el header (tamaño táctil cómodo en móvil).
class MusicPlayerBar extends StatelessWidget {
  const MusicPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final music = context.watch<BackgroundMusicController>();
    if (!music.settingsReady || !music.remoteEnabled || !music.hasTracks) {
      return const SizedBox.shrink();
    }

    if (music.disabled) {
      return _Btn(
        icon: Icons.music_note,
        tooltip: 'Activar música',
        onTap: music.toggleDisabled,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.wholesale.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (music.needsGesture)
            _Btn(
              icon: Icons.music_note,
              tooltip: 'Toca para oír',
              accent: true,
              onTap: music.tryPlay,
            ),
          _Btn(icon: Icons.skip_previous, tooltip: 'Anterior', onTap: music.prev),
          _Btn(
            icon: music.isPlaying ? Icons.pause : Icons.play_arrow,
            tooltip: music.isPlaying ? 'Pausar' : 'Reproducir',
            onTap: music.togglePlay,
          ),
          _Btn(icon: Icons.skip_next, tooltip: 'Siguiente', onTap: music.next),
          _Btn(
            icon: music.muted ? Icons.volume_off : Icons.volume_up,
            tooltip: music.muted ? 'Quitar silencio' : 'Silenciar',
            onTap: music.toggleMute,
          ),
          _Btn(
            icon: Icons.power_settings_new,
            tooltip: 'Quitar música',
            danger: true,
            onTap: music.toggleDisabled,
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.accent = false,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFEF4444)
        : accent
            ? const Color(0xFF0284C7)
            : AppColors.wholesale;
    final child = Material(
      color: accent
          ? const Color(0xFF0284C7).withValues(alpha: 0.12)
          : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
