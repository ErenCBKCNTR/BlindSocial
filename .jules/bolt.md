
## 2026-03-27 - [Optimize chat message sending by caching user/room data]
**Learning:** Repetitive database reads during frequent actions (like sending messages) significantly degrade UI responsiveness and increase I/O cost. Using simple in-memory state variables (`_cachedDisplayName`, `_cachedTtl`) for data that doesn't change during the lifecycle of a screen can effectively eliminate these redundant calls. Benchmarking these interactions with `WidgetTester` and a `Stopwatch` loop helps quantify the performance gains.
**Action:** Always scrutinize repetitive code paths (like message sending loops or builder functions) for synchronous or asynchronous I/O operations that can be cached. Pre-fetch or lazily fetch static data into state variables to avoid unnecessary overhead.

## 2026-03-27 - [Cache Firestore Streams]
**Learning:** Using `StreamBuilder` with dynamic values like `Timestamp.now()` directly in the `stream:` property (e.g., `where('expires_at', isGreaterThan: Timestamp.now())`) is a major performance anti-pattern. Because the widget rebuilds frequently (like when typing or recording audio), the inline `stream:` expression is re-evaluated with a *new* timestamp. This invalidates the cached query and forces a full database read on every render cycle, destroying performance.
**Action:** Always cache the base query stream in `initState` (`late final Stream<QuerySnapshot> _stream;`) to ensure the subscription remains stable across rebuilds. For dynamic time-based filtering, perform the filtering client-side within the `builder` method (`snapshot.data.docs.where(...)`) rather than constantly modifying the database query.

## 2026-03-27 - [Cache Firestore Streams: Server vs Client Filtering]
**Learning:** When moving a `StreamBuilder` query with `Timestamp.now()` from `build` to `initState` to prevent redundant reads, you must apply the time filter on *both* the server and client. If you remove the `.where('expires_at', isGreaterThan: now)` clause entirely from the server query, the stream downloads the entire unpaginated history of the collection (massive read penalty).
**Action:** Always capture the base timestamp in `initState` (`final now = Timestamp.now();`), include it in the Firestore query (`.where(...)`) to restrict the initial payload size, and then apply a dynamic `DateTime.now()` filter client-side within the `builder` to hide items that expire while the user is actively viewing the screen.

## 2026-03-27 - [Cache Inline Firestore Streams in StatefulWidget]
**Learning:** Using `StreamBuilder` with `FirebaseFirestore.instance.collection(...).snapshots()` directly in the `stream:` property inside a `build()` method is a major performance anti-pattern. Every time the widget rebuilds (e.g., from navigating or local `setState`), the inline expression is re-evaluated, tearing down the existing stream subscription and creating a completely new one. This causes a massive spike in unnecessary Firestore document reads, UI flickering, and heavy latency.
**Action:** Always extract the stream initialization from the `build()` method. Declare it as a `late final Stream<QuerySnapshot> _stream;` variable and assign it once inside `initState()`. If the query relies on a variable that changes (like a pagination limit), explicitly re-assign the stream only within the specific `setState` block where that variable is updated.

## 2026-03-29 - [Fix Livekit Client Compilation Error]
**Learning:** The `livekit_client` dependency deprecated the `position` argument in favor of `cameraPosition` for `CameraCaptureOptions`. Neglecting these library changes can lead to build failures that may go unnoticed until deployment or deep testing, causing delays.
**Action:** When an external dependency's compilation error mentions a missing named parameter, verify the changelog or update code to use the new parameter structure.

## 2026-03-29 - [Optimize Collection Length Queries with count()]
**Learning:** Using `snapshots().length` (or similar array-based methods after fetching docs) to get the total number of items in a Firestore collection is extremely inefficient and costly, because it downloads the entire collection structure and payloads to the client. This is a common performance bottleneck in admin dashboards.
**Action:** Always utilize the server-side aggregation method `FirebaseFirestore.instance.collection('...').count().get()` wrapped in a `FutureBuilder<AggregateQuerySnapshot>`. This shifts the computation entirely to the database, avoids downloading massive payloads, and reduces Firestore read costs significantly.

## 2024-03-30 - [Performance Improvement] Live Stream Module Update & Accessibility
**Learning:** Adding `connectivity_plus` to auth functions without mocking its method channel will break existing tests. To prevent test suites from hanging, use `MethodChannel('dev.fluttercommunity.plus/connectivity').setMockMethodCallHandler` returning `['wifi']` in `setUpAll`. For accessibility, when combining an Icon and a dynamic Text counter, wrap the Icon in a `Semantics` label containing both the action and the count, and wrap the Text in `ExcludeSemantics` to prevent double-reading by TalkBack.
**Action:** Always mock platform channels for hardware/system plugins when writing/updating widget tests. When designing accessible components, use `ExcludeSemantics` strategically to consolidate dynamic information into a single focusable `Semantics` node.

## 2026-03-31 - [Cache Subcollection Streams in StatefulWidget]
**Learning:** Instantiating a Firestore stream inside `StreamBuilder.stream` property for a deeply nested subcollection (e.g., `doc(id).collection('comments')`) in a `build()` method causes the stream subscription to tear down and recreate every time the user types or dictates text, resulting in highly redundant document reads.
**Action:** Extract nested subcollection streams to a `late final Stream<QuerySnapshot>` in `initState()` to persist the stream connection across widget rebuilds driven by local state changes (e.g., text inputs or dictation flags).

## 2024-03-30 - Firestore Indexing & Unblocking UI
**Learning:** Combining inequality (`where('field', isNotEqualTo: true)`) or multi-field equality (`where`) with `orderBy` on different fields requires a composite index, causing silent drops or StreamBuilder errors in production without it. Awaiting multiple Firebase deletes sequentially on close routines blocks the main UI thread during navigation.
**Action:** Always prefer server-side sorting (`orderBy`) and filter data client-side in the `StreamBuilder` if the resulting dataset is small. For component teardown, dispatch asynchronous operations (like `collection.get().then(...)`) and allow `Navigator.pop()` to execute immediately to ensure UI fluidity.

## 2024-03-31 - N+1 StreamBuilder pattern in ListView
**Learning:** Using `StreamBuilder` with inline `.snapshots()` inside a `ListView.builder` creates an N+1 query problem, exponentially increasing Firestore reads (N streams for N items) and triggering excessive widget rebuilds.
**Action:** When child items in a list need real-time data from a parent document or already-watched query, pass down the cached `Stream` initialized in the parent's `initState`, rather than instantiating new `.snapshots()` calls per child item.
