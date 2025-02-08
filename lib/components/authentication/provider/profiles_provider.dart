import 'dart:convert';

import 'package:bluesky/bluesky.dart' hide Preferences;
import 'package:bluesky/core.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/profile_data.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:harpy/core/preferences/preferences.dart';
import 'package:harpy/api/twitter/data/user_data.dart';
import 'package:logging/logging.dart';
import 'package:built_collection/built_collection.dart';

/// Provides access to stored profiles and handles profile switching.
final profilesProvider =
    StateNotifierProvider<ProfilesNotifier, StoredProfiles>((ref) {
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
    }
  }

  Future<void> addProfile(StoredProfileData profile) async {
    final profiles = List<StoredProfileData>.from(state.profiles);

    // Check if profile with same DID already exists
    final existingIndex = profiles.indexWhere((p) => p.did == profile.did);

    if (existingIndex != -1) {
      // Update existing profile with new credentials while preserving preferences
      final existingProfile = profiles[existingIndex];
      profiles[existingIndex] = profile.copyWith(
        mediaPreferences:
            profile.mediaPreferences ?? existingProfile.mediaPreferences,
        feedPreferences:
            profile.feedPreferences ?? existingProfile.feedPreferences,
        themeMode: profile.themeMode ?? existingProfile.themeMode,
        additionalPreferences: profile.additionalPreferences ??
            existingProfile.additionalPreferences,
        isActive: profile.isActive || existingProfile.isActive,
      );
      _log.fine('Updated existing profile for DID: ${profile.did}');
    } else {
      // If this is the first profile, make it active
      if (profiles.isEmpty) {
        profile = profile.copyWith(isActive: true);
      }
      profiles.add(profile);
      _log.fine('Added new profile for DID: ${profile.did}');
    }

    state = state.copyWith(profiles: profiles);
    await _saveProfiles();
  }

  Future<void> removeProfile(String did) async {
    final profiles = List<StoredProfileData>.from(state.profiles);
    profiles.removeWhere((profile) => profile.did == did);

    // If we removed the active profile, make another one active
    if (!profiles.any((profile) => profile.isActive) && profiles.isNotEmpty) {
      final firstProfile = profiles.first;
      profiles[0] = firstProfile.copyWith(isActive: true);
    }

    state = state.copyWith(profiles: profiles);
    await _saveProfiles();
  }

  Future<void> switchToProfile(String did) async {
    final profiles = List<StoredProfileData>.from(state.profiles);
    final index = profiles.indexWhere((profile) => profile.did == did);

    if (index == -1) return;

    // Deactivate current profile
    final currentActiveIndex =
        profiles.indexWhere((profile) => profile.isActive);
    if (currentActiveIndex != -1) {
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
    profiles[index] = newProfile.copyWith(isActive: true);

    state = state.copyWith(profiles: profiles);
    await _saveProfiles();

    // First invalidate all timeline providers
    _ref.invalidate(homeTimelineProvider);
    _ref.invalidate(userTimelineProvider(newProfile.did));
    _ref.invalidate(mediaTimelineProvider(BuiltList<BlueskyPostData>()));

    // Update feed preferences and ensure they're loaded
    if (newProfile.feedPreferences != null) {
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

    // If the active feed is not in the loaded feeds, default to following feed
    final feedPrefs = _ref.read(feedPreferencesProvider);
    final activeFeedUri = feedPrefs.activeFeedUri;
    if (activeFeedUri != null && activeFeedUri != 'app.bsky.feed.getTimeline') {
      final feedExists =
          feedPrefs.feeds.any((feed) => feed.uri == activeFeedUri);
      if (!feedExists) {
        await _ref
            .read(feedPreferencesProvider.notifier)
            .setActiveFeed('app.bsky.feed.getTimeline');
      }
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
          accessJwt: newProfile.accessJwt,
          refreshJwt: newProfile.refreshJwt,
          did: newProfile.did,
        );

    // Refresh the Bluesky API instance with new credentials
    final service = _ref.read(blueskyServiceProvider);
    final bluesky = Bluesky.fromSession(
      Session(
        did: newProfile.did,
        handle: newProfile.handle,
        accessJwt: newProfile.accessJwt,
        refreshJwt: newProfile.refreshJwt,
      ),
      service: service,
    );
    await _ref.read(blueskyApiProvider.notifier).setBlueskySession(bluesky);

    // Fetch latest profile data to update UI
    try {
      final profile = await bluesky.actor.getProfile(actor: newProfile.handle);

      // Update authentication state with fresh profile data
      final userData = UserData.fromBlueskyActorProfile(profile.data);
      _ref.read(authenticationStateProvider.notifier).state =
          AuthenticationState.authenticated(user: userData);

      // Update stored profile with latest data
      final updatedProfile = newProfile.copyWith(
        displayName: profile.data.displayName ?? profile.data.handle,
        avatar: profile.data.avatar,
      );

      final updatedProfiles = List<StoredProfileData>.from(state.profiles);
      final profileIndex = updatedProfiles.indexWhere((p) => p.did == did);
      if (profileIndex != -1) {
        updatedProfiles[profileIndex] = updatedProfile;
        state = state.copyWith(profiles: updatedProfiles);
        await _saveProfiles();
      }

      // Invalidate all timeline providers and reload feeds
      _ref.invalidate(homeTimelineProvider);
      _ref.invalidate(userTimelineProvider(userData.id));
      _ref.invalidate(mediaTimelineProvider(BuiltList<BlueskyPostData>()));

      // Load feeds for the new profile
      await _ref.read(feedPreferencesProvider.notifier).loadFeeds();

      // Reload the home timeline with the active feed
      await _ref.read(homeTimelineProvider.notifier).load(clearPrevious: true);
    } catch (e) {
      _log.warning('Failed to fetch latest profile data', e);
      // Still update auth state with stored data
      final userData = UserData(
        id: newProfile.did,
        name: newProfile.displayName,
        handle: newProfile.handle,
        profileImage: newProfile.avatar != null
            ? UserProfileImage.fromUrl(newProfile.avatar!)
            : null,
      );
      _ref.read(authenticationStateProvider.notifier).state =
          AuthenticationState.authenticated(user: userData);

      // Even if profile fetch fails, still invalidate timelines
      _ref.invalidate(homeTimelineProvider);
      _ref.invalidate(userTimelineProvider(userData.id));
      _ref.invalidate(mediaTimelineProvider(BuiltList<BlueskyPostData>()));

      // Load feeds for the new profile
      await _ref.read(feedPreferencesProvider.notifier).loadFeeds();

      // Reload the home timeline with the active feed
      await _ref.read(homeTimelineProvider.notifier).load(clearPrevious: true);
    }
  }

  StoredProfileData? getActiveProfile() {
    return state.profiles.firstWhereOrNull((profile) => profile.isActive);
  }
}
