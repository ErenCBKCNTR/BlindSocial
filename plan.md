1. **Accessibility**: Remove all `Semantics` widgets from the project. (Done)
2. **Themes**:
   - Open `lib/theme/app_theme.dart` and keep only `highContrastTheme`.
   - Open `lib/theme/theme_notifier.dart` and simplify it to only support `highContrastTheme`.
   - Open `lib/screens/profile_screen.dart`, locate the `_buildThemeSelector` widget method, and remove it. Simplify the layout logic in `build` so it always uses the original high contrast design layout without theme checking.
   - Run `read_file` to verify the modified files.
3. **Platform Appearance**:
   - Open `lib/screens/profile_screen.dart`. Use `grep` to locate the `Text('Platformda nasıl görünmek istersiniz?')` widget and its accompanying `DropdownButton`.
   - Replace the `DropdownButton` with two separate `ElevatedButton` or toggle buttons that update the `_displayPreference` state variable.
   - Use `read_file` to verify.
4. **Settings - Profile Update**:
   - Open `lib/screens/profile_screen.dart`.
   - Read the `_updateProfile` function and the initialization block `_loadUserData` to discover the baseline values. Add a tracking mechanism for original values (e.g., `_originalFullName`, `_originalUsername`, `_originalDisplayPref`, `_originalDay`, `_originalMonth`, `_originalYear`).
   - In `_updateProfile`, before any logic runs, compare the current values of `_fullNameController.text`, `_usernameController.text`, `_displayPreference`, and date fields to their `_original*` counterparts. If no differences exist, show a SnackBar with "Güncellenen değişiklik bulunamadı" and return early.
   - Use `read_file` to verify.
5. **Username Cooldown Error Message**:
   - Open `lib/screens/profile_screen.dart`.
   - Locate the `cooldown dakika beklemeniz gerekmektedir` error message in the catch block of `_updateProfile`. Replace `cooldown` with the string-interpolated `$rem` or correctly parsed minutes remaining from the Exception message.
   - Use `read_file` to verify.
6. **Games - Translation and Seeding**:
   - Open `lib/screens/games/trivia_game_screen.dart`. Review `initState` which currently immediately calls `_fetchQuestions()`.
   - Change the initial state so it first renders a setup UI with `DropdownButton` or similar for Category and Difficulty selection. Prevent `_fetchQuestions` from firing until a "Start" button is pressed.
   - Translate all identified English strings to Turkish.
   - In `_fetchQuestions` (or a similar start handler), check if `Games/{game_name}/Questions/{category_name}` is empty. If so, run a generation/seed script to insert 100 questions into Firestore. Update logic to fetch questions from Firestore instead of the remote HTTP API.
   - Use `read_file` to verify logic.
7. **Online Users**:
   - Open `lib/main.dart`, change `BlindSocialApp` state to use `WidgetsBindingObserver`. Implement `didChangeAppLifecycleState` to update `isOnline=1` or `0` for `FirebaseAuth.instance.currentUser?.uid` in the Firestore `users` collection.
   - Open `lib/screens/chat_rooms_screen.dart`. Under `DrawerHeader` containing "Blind Social Menü", add a new `StreamBuilder` widget that queries the `users` collection for `isOnline == 1`. Display the count of online users.
   - Use `read_file` to verify.
8. **BS Meydan - Report Bug**:
   - Open `lib/screens/square_screen.dart`. Read `_reportPost` to confirm it updates `reportedBy`. Modify it to write to a new `reported_posts` collection instead of or in addition to updating the post, and NEVER delete the post from this function.
   - Open `lib/screens/admin_panel_screen.dart`. Expand `TabBar` and `TabBarView` to 3 items, adding a "Şikayetler" tab. In the view, use a `StreamBuilder` on `reported_posts`. Render each as a `Card` showing the user/time and an `ElevatedButton` "Sil" wrapped in an authorization check (`currentUser.role_id == 0 || currentUser.role_id == 1`).
   - Use `read_file` to verify.
9. **BS Meydan - Timestamps**:
   - Open `lib/screens/square_screen.dart`. Locate the widget rendering the post content within the `StreamBuilder` of `meydan_posts` (likely a `ListTile` or `Card` returning from `itemBuilder`).
   - Write a helper function `_formatTimestamp(Timestamp t)` returning localized differences like "1s önce", "1g önce". Inject this formatted string into a `Text` widget below the post author's name inside the post rendering structure.
   - Use `read_file` to verify.
10. **BS Meydan - Comments & Actions**:
    - Open `lib/screens/square_screen.dart`. Inside the post rendering structure discovered above, add an `IconButton` for Comments. Tapping it opens a modal `showModalBottomSheet` containing a list of `post_comments` (new Firestore subcollection) and a `TextField` to add a new comment.
    - Inside the post rendering structure, add `IconButton`s for Edit and Delete. Conditionally render these if `post['authorId'] == currentUser.uid` or if `currentUserRole` (which must be fetched) is `0` or `1`. Add methods `_deletePost` and `_editPost` to handle the logic.
    - Use `read_file` to verify.
11. **Admin Panel UI**:
    - Open `lib/screens/admin_panel_screen.dart`. Refactor the `build` method. Instead of `DefaultTabController`, use a `Scaffold` body with a `GridView` or `Column` containing two `Card`s.
    - The first `Card` is "Odalar" and second is "Üyeler". Add `StreamBuilder`s to count the total documents in `chat_rooms` and `users` and display them on the cards.
    - Extract `_buildRoomList` and `_buildMemberList` into new custom widgets (e.g. `AdminPanelRoomsList` and `AdminPanelUsersList`) within the same file or new files. Wrap the cards in `InkWell` to push to these new screens via `Navigator`.
    - Use `read_file` to verify.
12. **Admin Panel Delete User**:
    - Open `lib/screens/admin_panel_user_details.dart`. Below the "Yetkiyi Güncelle" button, add an `ElevatedButton` styled red for "Üyeyi Sil". Write the `_deleteUser` method to delete the user document from Firestore.
    - Use `read_file` to verify.
13. **Cleanup**:
    - Verify iOS, macOS, Windows, Linux, Web folders are deleted (Done).
    - Clean up git branches using `git branch | grep -v "main" | xargs git branch -D` or similar.
14. **Logo**:
    - Edit `lib/screens/chat_rooms_screen.dart`. Find the `ListView` in the `Drawer`. At the bottom, add `Image.asset('assets/images/logo.png')`. Ensure `pubspec.yaml` has the asset entry (Done).
15. **Testing**:
    - Run the full test suite (`flutter test`) to ensure all changes are correct and no regressions were introduced.
16. **Pre-commit**:
    - Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.
