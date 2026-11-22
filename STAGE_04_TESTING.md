# Vanish Class Network — Stage 4 Testing Record

## 1. Code Review
- [x] Countdown uses relay server time.
- [x] App lifecycle observer added.
- [x] Expiry cleanup runs when app resumes.
- [x] Expired saved messages are filtered when server time is available.
- [x] SQLite cleanup uses relay-adjusted server time.
- [x] Flutter analyze completed with no issues.
- [x] Release APK built successfully.

## 2. Live Testing

| Test | Result |
|---|---|
| Offline message queue | Blocked — relay unavailable |
| Reconnection and queued delivery | Pending |
| Background countdown | Pending live verification |
| App restart and expiry | Pending live verification |
| Duplicate message prevention | Pending live verification |
| Expired message deletion | Pending live verification |

## 3. Current Limitation

The relay endpoint was unavailable during testing. Therefore, live network behavior and expiry synchronization across devices have not yet been verified after the latest code changes.

## 4. Next Action

Repeat the pending tests when the class relay becomes available.
