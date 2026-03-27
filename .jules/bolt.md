
## $(date +%Y-%m-%d) - [Optimize chat message sending by caching user/room data]
**Learning:** Repetitive database reads during frequent actions (like sending messages) significantly degrade UI responsiveness and increase I/O cost. Using simple in-memory state variables (`_cachedDisplayName`, `_cachedTtl`) for data that doesn't change during the lifecycle of a screen can effectively eliminate these redundant calls. Benchmarking these interactions with `WidgetTester` and a `Stopwatch` loop helps quantify the performance gains.
**Action:** Always scrutinize repetitive code paths (like message sending loops or builder functions) for synchronous or asynchronous I/O operations that can be cached. Pre-fetch or lazily fetch static data into state variables to avoid unnecessary overhead.
