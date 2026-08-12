import 'dart:async';
import 'dart:io' as io;
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
  final Completer<void> _initialization = Completer<void>();

  /// Completes when the restored session has produced its real profile.
  Future<void> get ready => _initialization.future;
  // Native Android sign-in uses the Android OAuth client automatically from
  // the package/SHA-1 configuration. The server client ID is the separate Web
  // OAuth client whose audience Supabase validates in the ID token.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: io.Platform.isIOS ? AppConfig.googleIosClientId : null,
    scopes: ['email', 'profile'],
    serverClientId: AppConfig.configuredGoogleClientId,
  );

  Future<void> _init() async {
    try {
      final sessionUser = SupabaseBootstrap.configured
          ? Supabase.instance.client.auth.currentUser
          : null;
      if (sessionUser != null && !sessionUser.isAnonymous) {
        final remoteProfile = await _loadRemoteProfile(sessionUser.id);
        if (remoteProfile != null) {
          state = remoteProfile;
          await _persistence.saveAuthenticatedProfile(remoteProfile);
          return;
        }

        final cachedAccount = await _persistence.loadAuthenticatedProfile();
        if (cachedAccount?.id == sessionUser.id) {
          state = cachedAccount!;
          return;
        }
      }

      final guestProfile =
          await _persistence.loadGuestProfile() ??
          PlayerProfile.guest(
            id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
            funnyUsername: UsernameGenerator.generateFunnyUsername(),
          );
      state = guestProfile;
      await _persistence.saveGuestProfile(guestProfile);
    } finally {
      if (!_initialization.isCompleted) _initialization.complete();
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
    if (updated.isGuest) {
      await _persistence.saveGuestProfile(updated);
    } else {
      await _persistence.saveAuthenticatedProfile(updated);
    }
    return true;
  }

  /// Sign in with Google account and merge eligible guest progress.
  Future<bool> signInWithGoogle({
    required void Function(String error) onError,
  }) async {
    // A Google identity alone is not a LetterLoom account. Without Supabase,
    // it cannot be persisted, restored, or used by Daily Challenge.
    if (!SupabaseBootstrap.configured) {
      onError(
        'Online services are unavailable in this app build. Please install a configured build.',
      );
      return false;
    }
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
      debugPrint(
        '[Auth] Google credentials received '
        '(idToken=${idToken.isNotEmpty}, accessToken=${accessToken.isNotEmpty})',
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

      // The remote profile is the durable source of truth after the first
      // successful sign-in. A guest profile may seed a brand-new account once,
      // but must never overwrite or add to an existing account on later logins.
      final existingRemote = SupabaseBootstrap.configured
          ? await _loadRemoteProfile(userId)
          : null;
      final guestProfile = state.isGuest
          ? state
          : await _persistence.loadGuestProfile();
      final String baseName = googleUser.displayName ?? 'LoomPlayer';
      // A guest becomes the user's first account identity. Keep the visible
      // name they already chose instead of generating a second username. Once
      // an account exists, its Supabase profile remains authoritative.
      String username =
          existingRemote?.username ??
          guestProfile?.username ??
          UsernameGenerator.generateFunnyUsername();

      // Ensure unique username
      if (existingRemote == null) {
        username = await _ensureUniqueUsername(username);
      }

      final mergedProfile = PlayerProfile(
        id: userId,
        username: username,
        displayName: existingRemote?.displayName ?? baseName,
        avatarId:
            existingRemote?.avatarId ?? guestProfile?.avatarId ?? 'avatar_owl',
        countryCode:
            existingRemote?.countryCode ?? guestProfile?.countryCode ?? 'US',
        isGuest: false,
        level: existingRemote?.level ?? 1,
        xp: existingRemote?.xp ?? 0,
        rankedTier: existingRemote?.rankedTier ?? 'Bronze III',
        rankedRating: existingRemote?.rankedRating ?? 1200,
        gamesPlayed: existingRemote?.gamesPlayed ?? 0,
        wins: existingRemote?.wins ?? 0,
        losses: existingRemote?.losses ?? 0,
        draws: existingRemote?.draws ?? 0,
        highestScore: existingRemote?.highestScore ?? 0,
        currentStreak: existingRemote?.currentStreak ?? 0,
        bestStreak: existingRemote?.bestStreak ?? 0,
        createdAt: existingRemote?.createdAt ?? DateTime.now(),
      );

      return await updateProfile(mergedProfile);
    } catch (e) {
      debugPrint('[Auth] Google Sign in error: $e');
      onError('Google Sign-In failed. Please try again.');
      return false;
    }
  }

  Future<PlayerProfile?> _loadRemoteProfile(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('player_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response == null ? null : PlayerProfile.fromJson(response);
    } catch (error) {
      debugPrint('[Auth] Could not load account profile: $error');
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
    final accountProfile = state.isGuest ? null : state;
    try {
      await _googleSignIn.signOut();
      if (SupabaseBootstrap.configured) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}

    var guestProfile =
        await _persistence.loadGuestProfile() ??
        PlayerProfile.guest(
          id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
          funnyUsername: UsernameGenerator.generateFunnyUsername(),
        );

    // The guest keeps separate local progression, but signing out should not
    // make the UI look like it switched to a different person. Mirror only
    // safe display fields from the account; never copy account stats or its
    // Supabase user id into guest storage.
    if (accountProfile != null) {
      guestProfile = guestProfile.copyWith(
        username: accountProfile.username,
        displayName: accountProfile.displayName,
        avatarId: accountProfile.avatarId,
        countryCode: accountProfile.countryCode,
      );
    }
    state = guestProfile;
    await _persistence.saveGuestProfile(guestProfile);
  }
}
