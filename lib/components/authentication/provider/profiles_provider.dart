import 'dart:convert';

import 'package:bluesky/atproto.dart' show createSession, refreshSession;
import 'package:bluesky/bluesky.dart' hide Preferences;
import 'package:bluesky/core.dart';
import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/data/profile_data.dart';
import 'package:harpy/api/bluesky/data/session_data.dart';
import 'package:harpy/api/twitter/data/user_data.dart';
import 'package:harpy/components/authentication/widgets/retry_authentication_dialog.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:harpy/core/preferences/preferences.dart';
import 'package:logging/logging.dart';

/// Provides access to stored profiles and handles profile switching.
final profilesProvider = StateNotifierProvider<ProfilesNotifier, StoredProfiles>((ref) {
  return ProfilesNotifier(
    preferences: ref.watch(encryptedPreferencesProvider(null)),
    ref: ref,
  );
});

class ProfilesNotifier extends StateNotifier<StoredProfiles> {
  ProfilesNotifier({
    required Preferences preferences,
    required Ref ref,
  })  : _preferences = preferences,
        _ref = ref,
        super(const StoredProfiles()) {
    _initialize();
  }

  final Preferences _preferences;
  final Ref _ref;
  final _log = Logger('ProfilesNotifier');

  void _initialize() {
    final profilesJson = _preferences.getString('stored_profiles');
    if (profilesJson.isNotEmpty) {
      try {
        state = StoredProfiles.fromJson(
          jsonDecode(profilesJson) as Map<String, dynamic>,
        );
      } catch (e) {
        _log.warning('Failed to load stored profiles', e);
      }
    }
  }

  Future<void> _saveProfiles() async {
    try {
      await _preferences.setString(
        'stored_profiles',
        jsonEncode(state.toJson()),
      );
    } catch (e) {
      _log.severe('Failed to save profiles', e);
      _ref.read(messageServiceProvider).showText('Failed to save profile changes');
      rethrow;
    }
  }

  Future<void> addProfile(StoredProfileData profile) async {
    state = state.copyWith(isProfileSwitching: true);
    try {
      final profiles = List<StoredProfileData>.from(state.profiles);

      // Check if profile with same DID already exists
      final existingIndex = profiles.indexWhere((p) => p.did == profile.did);

      if (existingIndex != -1) {
        // Update existing profile with new credentials while preserving preferences
        final existingProfile = profiles[existingIndex];
        profiles[existingIndex] = profile.copyWith(
          mediaPreferences: profile.mediaPreferences ?? existingProfile.mediaPreferences,
          feedPreferences: profile.feedPreferences ?? existingProfile.feedPreferences,
          themeMode: profile.themeMode ?? existingProfile.themeMode,
          additionalPreferences:
              profile.additionalPreferences ?? existingProfile.additionalPreferences,
          isActive: profile.isActive || existingProfile.isActive,
        );
        _log.fine('Updated existing profile for DID: ${profile.did}');
        _ref.read(messageServiceProvider).showText('Welcome back! Your profile has been updated');
      } else {
        // If this is the first profile, make it active
        if (profiles.isEmpty) {
          profile = profile.copyWith(isActive: true);
        }
        profiles.add(profile);
        _log.fine('Added new profile for DID: ${profile.did}');
        _ref.read(messageServiceProvider).showText('Welcome to Harpy! Your profile has been added');
      }

      state = state.copyWith(profiles: profiles);
      await _saveProfiles();
    } catch (e) {
      _log.severe('Failed to add/update profile', e);
      _ref.read(messageServiceProvider).showText(
            'Unable to add your profile. Please check your connection and try again',
          );
      rethrow;
    } finally {
      state = state.copyWith(isProfileSwitching: false);
    }
  }

  Future<void> removeProfile(String did) async {
    state = state.copyWith(isProfileSwitching: true);
    try {
      final profiles = List<StoredProfileData>.from(state.profiles);

      // Check if we're trying to remove the last profile
      if (profiles.length <= 1) {
        _log.warning('Attempted to remove last profile');
        _ref.read(messageServiceProvider).showText(
              'You need at least one profile to use Harpy. Add another profile before removing this one',
            );
        return;
      }

      // Check if profile exists before removal
      final profileToRemove = profiles.firstWhereOrNull((profile) => profile.did == did);
      if (profileToRemove == null) {
        _log.warning('Attempted to remove non-existent profile');
        _ref.read(messageServiceProvider).showText('This profile no longer exists');
        return;
      }

      // If we're removing the active profile, we need to switch to another one first
      if (profileToRemove.isActive) {
        // Find another profile to switch to
        final nextProfile = profiles.firstWhere((p) => p.did != did);
        _log.fine('Switching to profile ${nextProfile.did} before removal');
        await switchToProfile(nextProfile.did);
      }

      profiles.removeWhere((profile) => profile.did == did);
      _log.fine('Removed profile with DID: $did');

      state = state.copyWith(profiles: profiles);
      await _saveProfiles();

      _ref.read(messageServiceProvider).showText('Profile removed successfully');
    } catch (e) {
      _log.severe('Failed to remove profile', e);
      _ref.read(messageServiceProvider).showText(
            'Unable to remove profile. Please try again',
          );
      rethrow;
    } finally {
      state = state.copyWith(isProfileSwitching: false);
    }
  }

  /// Attempts to auto-login with the last active profile.
  /// Returns true if auto-login was successful, false otherwise.
  Future<bool> attemptAutoLogin() async {
    state = state.copyWith(isProfileSwitching: true);
    try {
      // Find the active profile or the last used profile
      final activeProfile =
          getActiveProfile() ?? (state.profiles.isNotEmpty ? state.profiles.last : null);

      if (activeProfile == null) {
        _log.fine('No stored profiles found for auto-login');
        return false;
      }

      _log.fine('Attempting auto-login with profile: ${activeProfile.handle}');

      // Set awaiting authentication state
      _ref.read(authenticationStateProvider.notifier).state =
          const AuthenticationState.awaitingAuthentication();

      // Try to switch to the profile - this will handle all the session management
      try {
        // First try to refresh the session
        await _refreshProfileSession(activeProfile);

        // Get the updated profile after refresh
        final updatedProfile = state.profiles.firstWhere(
          (p) => p.did == activeProfile.did,
        );

        // Create new Bluesky client with the refreshed session
        final updatedClient = Bluesky.fromSession(
          Session(
            did: updatedProfile.did,
            handle: updatedProfile.handle,
            accessJwt: updatedProfile.accessJwt,
            refreshJwt: updatedProfile.refreshJwt,
          ),
          service: _ref.read(blueskyServiceProvider),
        );

        // Update the Bluesky client provider
        await _ref.read(blueskyApiProvider.notifier).setBlueskySession(updatedClient);

        // Now switch to the profile
        await switchToProfile(activeProfile.did, suppressMessages: true);
        _log.fine('Auto-login successful for profile: ${activeProfile.handle}');

        // Navigate based on setup status
        if (_ref.read(setupPreferencesProvider).performedSetup) {
          _ref.read(routerProvider).goNamed(HomePage.name);
        } else {
          _ref.read(routerProvider).goNamed(SetupPage.name);
        }

        return true;
      } on SessionExpiredException {
        _log.fine('Session expired for profile: ${activeProfile.handle}');

        // Try to re-authenticate with stored credentials
        try {
          final service = _ref.read(blueskyServiceProvider);
          final session = await createSession(
            service: service,
            identifier: activeProfile.handle,
            password: activeProfile.appPassword,
          );

          // Update the profile with new session
          final profiles = List<StoredProfileData>.from(state.profiles);
          final index = profiles.indexWhere((p) => p.did == activeProfile.did);
          profiles[index] = activeProfile.copyWith(
            accessJwt: session.data.accessJwt,
            refreshJwt: session.data.refreshJwt,
          );
          state = state.copyWith(profiles: profiles);
          await _saveProfiles();

          // Create new Bluesky client
          final updatedClient = Bluesky.fromSession(
            session.data,
            service: service,
          );
          await _ref.read(blueskyApiProvider.notifier).setBlueskySession(updatedClient);

          // Now try switching to the profile again
          await switchToProfile(activeProfile.did, suppressMessages: true);
          _log.fine('Auto re-authentication successful for profile: ${activeProfile.handle}');

          // Navigate based on setup status
          if (_ref.read(setupPreferencesProvider).performedSetup) {
            _ref.read(routerProvider).goNamed(HomePage.name);
          } else {
            _ref.read(routerProvider).goNamed(SetupPage.name);
          }

          return true;
        } catch (e) {
          _log.warning('Auto re-authentication failed', e);
          // Show re-authentication dialog on next user interaction
          _ref.read(authenticationStateProvider.notifier).state =
              const AuthenticationState.unauthenticated();
          return false;
        }
      }
    } catch (e) {
      _log.severe('Auto-login failed with error', e);
      _ref.read(authenticationStateProvider.notifier).state =
          const AuthenticationState.unauthenticated();
      return false;
    } finally {
      state = state.copyWith(isProfileSwitching: false);
    }
  }

  Future<void> _refreshProfileSession(StoredProfileData profile) async {
    final service = _ref.read(blueskyServiceProvider);
    final profiles = List<StoredProfileData>.from(state.profiles);
    final index = profiles.indexWhere((p) => p.did == profile.did);

    if (index == -1) {
      throw Exception('Profile not found');
    }

    // Create session data to check expiration
    final session = SessionData(
      accessJwt: profile.accessJwt,
      refreshJwt: profile.refreshJwt,
      did: profile.did,
      handle: profile.handle,
    );

    try {
      // Check if session is near expiry or expired
      if (session.isExpired() || session.isNearExpiry()) {
        _log.fine('Session expired or near expiry, attempting refresh');

        // First try to refresh if the refresh token is still valid
        if (!session.isRefreshExpired()) {
          try {
            final refreshed = await refreshSession(
              service: service,
              refreshJwt: profile.refreshJwt,
            );

            // Update stored profile
            profiles[index] = profile.copyWith(
              accessJwt: refreshed.data.accessJwt,
              refreshJwt: refreshed.data.refreshJwt,
            );

            // Create new Bluesky client with refreshed session
            final updatedClient = Bluesky.fromSession(
              Session(
                did: profile.did,
                handle: profile.handle,
                accessJwt: refreshed.data.accessJwt,
                refreshJwt: refreshed.data.refreshJwt,
              ),
              service: service,
            );

            // Update the Bluesky client provider
            await _ref.read(blueskyApiProvider.notifier).setBlueskySession(updatedClient);

            _log.fine('Session refreshed successfully');
            state = state.copyWith(profiles: profiles);
            await _saveProfiles();
            return;
          } catch (e) {
            _log.warning('Failed to refresh session', e);
          }
        }

        // If refresh fails or refresh token is expired, try re-authentication
        try {
          _log.fine('Attempting re-authentication with stored credentials');
          final newSession = await createSession(
            service: service,
            identifier: profile.handle,
            password: profile.appPassword,
          );

          // Update stored profile
          profiles[index] = profile.copyWith(
            accessJwt: newSession.data.accessJwt,
            refreshJwt: newSession.data.refreshJwt,
          );

          // Create new Bluesky client with new session
          final updatedClient = Bluesky.fromSession(
            newSession.data,
            service: service,
          );

          // Update the Bluesky client provider
          await _ref.read(blueskyApiProvider.notifier).setBlueskySession(updatedClient);

          _log.fine('Re-authentication successful');
          state = state.copyWith(profiles: profiles);
          await _saveProfiles();
          return;
        } catch (e) {
          _log.warning('Re-authentication failed', e);

          // If re-auth with stored credentials fails, show re-auth dialog
          if (!profile.isActive) {
            throw SessionExpiredException(profile);
          }

          final dialogService = _ref.read(dialogServiceProvider);
          final success = await dialogService.show<bool>(
            child: RetryAuthenticationDialog(initialIdentifier: profile.handle),
          );

          if (success != true) {
            throw SessionExpiredException(profile);
          }

          // If user successfully re-authenticated through the dialog,
          // the session will be updated by the login provider
          return;
        }
      } else {
        // Even if session is valid, ensure we have a proper Bluesky client
        final currentClient = _ref.read(blueskyApiProvider);
        if (currentClient.session?.did != profile.did) {
          _log.fine('Session valid but client needs update');
          final updatedClient = Bluesky.fromSession(
            Session(
              did: profile.did,
              handle: profile.handle,
              accessJwt: profile.accessJwt,
              refreshJwt: profile.refreshJwt,
            ),
            service: service,
          );
          await _ref.read(blueskyApiProvider.notifier).setBlueskySession(updatedClient);
        }
      }

      // Session is still valid, no action needed
      _log.fine('Session is still valid');
    } catch (e) {
      _log.severe('Session refresh failed', e);
      throw SessionExpiredException(profile);
    }
  }

  Future<void> switchToProfile(
    String did, {
    bool suppressMessages = false,
  }) async {
    state = state.copyWith(isProfileSwitching: true);
    try {
      final profiles = List<StoredProfileData>.from(state.profiles);
      final index = profiles.indexWhere((profile) => profile.did == did);

      if (index == -1) {
        throw Exception('Profile not found');
      }

      // Deactivate current profile
      final currentActiveIndex = profiles.indexWhere((profile) => profile.isActive);
      if (currentActiveIndex >= 0) {
        // Store current preferences before switching
        final currentProfile = profiles[currentActiveIndex];
        profiles[currentActiveIndex] = currentProfile.copyWith(
          isActive: false,
          mediaPreferences: _ref.read(mediaPreferencesProvider),
          feedPreferences: _ref.read(feedPreferencesProvider),
          themeMode: _ref.read(themeProvider).themeMode.name,
        );
      }

      // Activate new profile
      final newProfile = profiles[index];

      // Show switching message
      if (!suppressMessages) {
        _ref.read(messageServiceProvider).showText(
              "Switching to ${newProfile.displayName}'s profile...",
            );
      }

      // Refresh the session before switching
      try {
        await _refreshProfileSession(newProfile);
        profiles[index] = state.profiles[index]; // Get the updated profile with new tokens
      } catch (e) {
        if (e is SessionExpiredException) {
          if (!suppressMessages) {
            _ref.read(messageServiceProvider).showText(
                  'Your session has expired. Please sign in again to continue',
                );
          }
          _ref.read(authenticationStateProvider.notifier).state =
              const AuthenticationState.unauthenticated();
          rethrow;
        }
        rethrow;
      }

      // Update feed preferences and ensure they're loaded
      if (newProfile.feedPreferences?.feeds.isNotEmpty ?? false) {
        await _ref
            .read(feedPreferencesProvider.notifier)
            .updateFromStoredPreferences(newProfile.feedPreferences!);
      } else {
        // If no feed preferences exist, set default following feed
        await _ref
            .read(feedPreferencesProvider.notifier)
            .setActiveFeed('app.bsky.feed.getTimeline');
      }

      // Always load feeds to ensure we have the latest custom feeds for this profile
      await _ref.read(feedPreferencesProvider.notifier).loadFeeds();

      // Update the active profile
      profiles[index] = newProfile.copyWith(isActive: true);
      state = state.copyWith(profiles: profiles);
      await _saveProfiles();

      // Apply the stored preferences
      if (newProfile.mediaPreferences != null) {
        _ref
            .read(mediaPreferencesProvider.notifier)
            .updateFromStoredPreferences(newProfile.mediaPreferences!);
      }

      if (newProfile.themeMode != null) {
        await _ref.read(themeProvider.notifier).setThemeMode(
              ThemeMode.values.byName(newProfile.themeMode!),
            );
      }

      // Update authentication state
      await _ref.read(authPreferencesProvider.notifier).setBlueskyAuth(
            handle: newProfile.handle,
            password: newProfile.appPassword,
          );

      await _ref.read(authPreferencesProvider.notifier).setBlueskySession(
            accessJwt: state.profiles[index].accessJwt,
            refreshJwt: state.profiles[index].refreshJwt,
            did: newProfile.did,
          );

      // Create new Bluesky client with current session
      final service = _ref.read(blueskyServiceProvider);
      final updatedClient = Bluesky.fromSession(
        Session(
          did: newProfile.did,
          handle: newProfile.handle,
          accessJwt: state.profiles[index].accessJwt,
          refreshJwt: state.profiles[index].refreshJwt,
        ),
        service: service,
      );

      // Update the Bluesky client provider
      await _ref.read(blueskyApiProvider.notifier).setBlueskySession(updatedClient);

      // Fetch latest profile data to update UI and set authentication state
      try {
        final profile = await updatedClient.actor.getProfile(actor: newProfile.handle);

        // Update authentication state with fresh profile data
        final userData = UserData.fromBlueskyActorProfile(profile.data);
        _ref.read(authenticationStateProvider.notifier).state =
            AuthenticationState.authenticated(user: userData);

        // Update stored profile with latest data
        final updatedProfile = profiles[index].copyWith(
          displayName: profile.data.displayName ?? profile.data.handle,
          avatar: profile.data.avatar,
          isActive: true,
        );
        profiles[index] = updatedProfile;
        state = state.copyWith(profiles: profiles);
        await _saveProfiles();

        // Now invalidate timeline providers after authentication is confirmed
        _ref.invalidate(homeTimelineProvider);
        _ref.invalidate(userTimelineProvider(newProfile.did));
        _ref.invalidate(
          mediaTimelineProvider(BuiltList<BlueskyPostData>.of([])),
        );

        // Reload the home timeline with the active feed
        await _ref.read(homeTimelineProvider.notifier).load(clearPrevious: true);
      } catch (e) {
        _log.warning('Failed to fetch latest profile data', e);
        // Still update auth state with stored data
        final userData = UserData(
          id: newProfile.did,
          name: newProfile.displayName,
          handle: newProfile.handle,
          profileImage:
              newProfile.avatar != null ? UserProfileImage.fromUrl(newProfile.avatar!) : null,
        );
        _ref.read(authenticationStateProvider.notifier).state =
            AuthenticationState.authenticated(user: userData);

        // Mark profile as active even if we couldn't fetch latest data
        profiles[index] = profiles[index].copyWith(isActive: true);
        state = state.copyWith(profiles: profiles);
        await _saveProfiles();

        // Now invalidate timeline providers after authentication is confirmed
        _ref.invalidate(homeTimelineProvider);
        _ref.invalidate(userTimelineProvider(newProfile.did));
        _ref.invalidate(
          mediaTimelineProvider(BuiltList<BlueskyPostData>.of([])),
        );

        // Reload the home timeline with the active feed
        await _ref.read(homeTimelineProvider.notifier).load(clearPrevious: true);
      }

      // Show success message at the end
      if (!suppressMessages) {
        _ref.read(messageServiceProvider).showText(
              'Welcome back, ${newProfile.displayName}!',
            );
      }
    } catch (e) {
      if (e is SessionExpiredException) {
        rethrow;
      }
      _log.severe('Failed to switch profile', e);
      _ref.read(messageServiceProvider).showText(
            'Unable to switch profiles. Please check your connection and try again',
          );
      rethrow;
    } finally {
      state = state.copyWith(isProfileSwitching: false);
    }
  }

  StoredProfileData? getActiveProfile() {
    return state.profiles.firstWhereOrNull((profile) => profile.isActive);
  }
}

/// Exception thrown when a session has expired and needs re-authentication
class SessionExpiredException implements Exception {
  SessionExpiredException(this.profile);
  final StoredProfileData profile;
}
