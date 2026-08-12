import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/player_profile.dart';
import '../../storage/persistence_manager.dart';
import '../../core/supabase_bootstrap.dart';
import '../../core/app_config.dart';
import '../profile/username_generator.dart';

final authProvider = StateNotifierProvider<AuthNotifier, PlayerProfile>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<PlayerProfile> {
  AuthNotifier()
    : super(
        PlayerProfile.guest(
          id: 'guest_init',
          funnyUsername: UsernameGenerator.generateFunnyUsername(),
        ),
      ) {
    _init();
  }

  final PersistenceManager _persistence = PersistenceManager();
  // Native Android sign-in uses the Android OAuth client automatically from
  // the package/SHA-1 configuration. The server client ID is the separate Web
  // OAuth client whose audience Supabase validates in the ID token.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: AppConfig.googleIosClientId,
    scopes: ['email', 'profile'],
    serverClientId: AppConfig.configuredGoogleClientId,
  );

  Future<void> _init() async {
    final savedProfile = await _persistence.loadProfile();
    if (savedProfile != null) {
      state = savedProfile;
    } else {
      final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final funnyUsername = UsernameGenerator.generateFunnyUsername();
      final guestProfile = PlayerProfile.guest(
        id: guestId,
        funnyUsername: funnyUsername,
      );
      state = guestProfile;
      await _persistence.saveProfile(guestProfile);
    }
  }

  /// Update the current profile in memory and local storage.
  Future<bool> updateProfile(PlayerProfile updated) async {
    if (!updated.isGuest && SupabaseBootstrap.configured) {
      final sessionUser = Supabase.instance.client.auth.currentUser;
      if (sessionUser == null || sessionUser.isAnonymous) {
        debugPrint(
          '[Auth] Refusing to sync a signed-in profile without a session.',
        );
        return false;
      }
      final profileId = sessionUser.id;
      try {
        // Only profile-display fields are client editable. Progression,
        // economy, and competitive fields are server-owned.
        await Supabase.instance.client.from('player_profiles').upsert({
          'id': profileId,
          'username': updated.username,
          'lower_username': updated.username.toLowerCase(),
          'display_name': updated.displayName,
          'avatar_id': updated.avatarId,
          'country_code': updated.countryCode,
        }, onConflict: 'id');
      } catch (e) {
        debugPrint('[Auth] Error syncing profile to Supabase: $e');
        return false;
      }
    }
    state = updated;
    await _persistence.saveProfile(updated);
    return true;
  }

  /// Sign in with Google account and merge eligible guest progress.
  Future<bool> signInWithGoogle({
    required void Function(String error) onError,
  }) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String idToken = googleAuth.idToken ?? '';
      final String accessToken = googleAuth.accessToken ?? '';
      final googleNonce = _nonceClaim(idToken);
      debugPrint(
        '[Auth] Google credentials received '
        '(idToken=${idToken.isNotEmpty}, accessToken=${accessToken.isNotEmpty}, '
        'nonceClaim=${googleNonce != null})',
      );

      if (idToken.isEmpty || accessToken.isEmpty) {
        debugPrint(
          '[Auth] Google SDK returned incomplete credentials '
          '(idToken=${idToken.isNotEmpty}, accessToken=${accessToken.isNotEmpty})',
        );
        onError('Google Sign-In did not return complete credentials.');
        return false;
      }

      String userId = googleUser.id;
      if (SupabaseBootstrap.configured) {
        final currentUser = Supabase.instance.client.auth.currentUser;
        AuthResponse res;
        // Do not link an ID token to the anonymous session. Supabase
        // anonymous sessions can carry a nonce, while google_sign_in's
        // token does not; linking then fails with a nonce mismatch. The
        // guest profile is local and is merged below after normal sign-in.
        if (currentUser?.isAnonymous == true) {
          await Supabase.instance.client.auth.signOut();
        }
        try {
          res = await Supabase.instance.client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
            nonce: googleNonce,
          );
        } catch (signInError) {
          debugPrint('[Auth] Supabase Google sign-in error: $signInError');
          onError(
            'Google Sign-In could not connect to LetterLoom. Please try again.',
          );
          return false;
        }
        if (res.user == null) {
          onError('Google Sign-In did not create a LetterLoom account.');
          return false;
        }
        userId = res.user!.id;
      } else if (SupabaseBootstrap.configured) {
        onError('Google Sign-In did not return a valid identity token.');
        return false;
      }

      // Check if remote profile already exists
      PlayerProfile? existingRemote;
      if (SupabaseBootstrap.configured) {
        try {
          final response = await Supabase.instance.client
              .from('player_profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
          if (response != null) {
            existingRemote = PlayerProfile.fromJson(response);
          }
        } catch (_) {}
      }

      final guestProfile = state;
      final String baseName = googleUser.displayName ?? 'LoomPlayer';
      String username =
          existingRemote?.username ?? UsernameGenerator.generateFunnyUsername();

      // Ensure unique username
      if (existingRemote == null) {
        username = await _ensureUniqueUsername(username);
      }

      final mergedProfile = PlayerProfile(
        id: userId,
        username: username,
        displayName: existingRemote?.displayName ?? baseName,
        avatarId: existingRemote?.avatarId ?? guestProfile.avatarId,
        countryCode: existingRemote?.countryCode ?? guestProfile.countryCode,
        isGuest: false,
        level: max(existingRemote?.level ?? 1, guestProfile.level),
        xp: max(existingRemote?.xp ?? 0, guestProfile.xp),
        rankedTier: existingRemote?.rankedTier ?? guestProfile.rankedTier,
        rankedRating: max(
          existingRemote?.rankedRating ?? 1200,
          guestProfile.rankedRating,
        ),
        gamesPlayed:
            (existingRemote?.gamesPlayed ?? 0) + guestProfile.gamesPlayed,
        wins: (existingRemote?.wins ?? 0) + guestProfile.wins,
        losses: (existingRemote?.losses ?? 0) + guestProfile.losses,
        draws: (existingRemote?.draws ?? 0) + guestProfile.draws,
        highestScore: max(
          existingRemote?.highestScore ?? 0,
          guestProfile.highestScore,
        ),
        currentStreak: max(
          existingRemote?.currentStreak ?? 0,
          guestProfile.currentStreak,
        ),
        bestStreak: max(
          existingRemote?.bestStreak ?? 0,
          guestProfile.bestStreak,
        ),
        createdAt: existingRemote?.createdAt ?? DateTime.now(),
      );

      return await updateProfile(mergedProfile);
    } catch (e) {
      debugPrint('[Auth] Google Sign in error: $e');
      onError('Google Sign-In failed. Please try again.');
      return false;
    }
  }

  String? _nonceClaim(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final nonce = payload is Map<String, dynamic> ? payload['nonce'] : null;
      return nonce is String && nonce.isNotEmpty ? nonce : null;
    } catch (_) {
      return null;
    }
  }

  /// Ensure username uniqueness against backend or generator.
  Future<String> _ensureUniqueUsername(String candidate) async {
    String current = candidate;
    int attempts = 0;
    while (attempts < 10) {
      bool isTaken = false;
      if (SupabaseBootstrap.configured) {
        try {
          final res = await Supabase.instance.client
              .from('player_profiles')
              .select('id')
              .eq('lower_username', current.toLowerCase())
              .maybeSingle();
          if (res != null) {
            isTaken = true;
          }
        } catch (_) {}
      }

      if (!isTaken) return current;
      current = UsernameGenerator.generateWithSuffix(candidate);
      attempts++;
    }
    return '${candidate}_${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  /// Sign out authenticated account and revert safely to Guest profile.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      if (SupabaseBootstrap.configured) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}

    final guestProfile = PlayerProfile.guest(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      funnyUsername: UsernameGenerator.generateFunnyUsername(),
    );
    state = guestProfile;
    await _persistence.saveProfile(guestProfile);
  }
}
