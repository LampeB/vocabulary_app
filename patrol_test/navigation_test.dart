import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'helpers/steps.dart';
import 'helpers/test_helpers.dart';

// Navigation net: proves every signed-in destination is reachable and renders
// its own screen. Covers the four bottom-nav tabs, the raised centre Study
// button, the Home header bell, the Profile nav tiles, and a list → detail tap.
//
// Assertions use screen-root keys (WidgetKeys.screen*), never localized text, so
// a copy/locale change can't break them — only an actual routing regression can.
// Every destination lives inside the shell, so the bottom nav stays visible and
// each test returns to a known screen via a tab tap (no fragile back-presses).

const _navList = 'E2E Nav Test List';

void main() {
  // Each bottom-nav tab opens its corresponding screen.
  patrolTest('Navigation — bottom-nav tabs open Home, Lists, Social, Profile',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate();
    await app.then.onScreen(Screen.home);

    await app.when.tapsNavTab(NavTab.lists);
    await app.then.onScreen(Screen.lists);

    await app.when.tapsNavTab(NavTab.social);
    await app.then.onScreen(Screen.social);

    await app.when.tapsNavTab(NavTab.profile);
    await app.then.onScreen(Screen.profile);

    await app.when.tapsNavTab(NavTab.home);
    await app.then.onScreen(Screen.home);
  });

  // The raised centre Study button opens the Start-a-session screen.
  patrolTest('Navigation — Study button opens Start-a-session',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate();
    await app.when.opensStartASession();
    await app.then.onScreen(Screen.startSession);

    await app.when.tapsNavTab(NavTab.home);
    await app.then.onScreen(Screen.home);
  });

  // The Home header bell opens Notification settings.
  patrolTest('Navigation — Home bell opens Notifications',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate();
    await app.then.onScreen(Screen.home);

    await app.when.opensNotificationsFromBell();
    await app.then.onScreen(Screen.notifications);

    await app.when.tapsNavTab(NavTab.home);
    await app.then.onScreen(Screen.home);
  });

  // The Profile nav tiles open Stats, Settings, and Notifications in turn.
  patrolTest('Navigation — Profile tiles open Stats, Settings, Notifications',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate();
    await app.when.tapsNavTab(NavTab.profile);
    await app.then.onScreen(Screen.profile);

    await app.when.opensProfileTile(ProfileTile.stats);
    await app.then.onScreen(Screen.stats);
    await app.when.tapsNavTab(NavTab.profile);
    await app.then.onScreen(Screen.profile);

    await app.when.opensProfileTile(ProfileTile.settings);
    await app.then.onScreen(Screen.settings);
    await app.when.tapsNavTab(NavTab.profile);
    await app.then.onScreen(Screen.profile);

    await app.when.opensProfileTile(ProfileTile.notifications);
    await app.then.onScreen(Screen.notifications);

    await app.when.tapsNavTab(NavTab.home);
    await app.then.onScreen(Screen.home);
  });

  // Tapping a list on the Lists screen opens its detail screen.
  patrolTest('Navigation — tapping a list opens its detail',
      timeout: const Timeout(Duration(minutes: 7)),
      config: kFastSettle, ($) async {
    final app = Steps($);
    addTearDown(() => deleteAllLists($)); // leave a clean slate (even on failure)

    await app.given.signedIn();
    await app.given.aCleanSlate();
    await app.given
        .aListWithOneWord(name: _navList, french: 'bonjour', korean: '안녕');

    await app.when.tapsNavTab(NavTab.lists);
    await app.then.onScreen(Screen.lists);

    await app.when.opensList(_navList);
    await app.then.onScreen(Screen.listDetail);

    await app.when.tapsNavTab(NavTab.home);
    await app.then.onScreen(Screen.home);
  });
}
