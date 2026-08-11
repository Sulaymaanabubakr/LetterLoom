import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_config.dart';
import '../../core/supabase_bootstrap.dart';
import '../auth/auth_service.dart';

final progressionProvider = Provider<ProgressionService>((ref) {
  return ProgressionService(ref);
});

class ProgressionService {
  final Ref _ref;
  Future<void> _updateQueue = Future<void>.value();
  ProgressionService(this._ref);

  /// Award XP to current player profile and recalculate level.
  Future<void> addXP(int amount, {required String reason}) async {
    if (amount <= 0) return;
    final user = SupabaseBootstrap.configured
        ? Supabase.instance.client.auth.currentUser
        : null;
    // Authenticated progression must come from server-verified events. Do not
    // let a modified client create local XP that looks like account progress.
    if (user != null && !user.isAnonymous) return;
    _updateQueue = _updateQueue.then((_) async {
      final current = _ref.read(authProvider);
      final newXP = current.xp + amount;
      final newLevel = AppConfig.levelForXP(newXP);
      final updated = current.copyWith(xp: newXP, level: newLevel);
      await _ref.read(authProvider.notifier).updateProfile(updated);
      debugPrint('[Progression] Awarded $amount XP ($reason). New Level: $newLevel ($newXP total XP).');
    });
    await _updateQueue;
  }
}
