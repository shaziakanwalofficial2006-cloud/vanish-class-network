# Vanish Relay Protocol v1 (proposal)

Proposed by Sawaira Waheed. Pending agreement at the Day 2 protocol review.

- **Relay address:** `wss://vanish-relay-sawaira.bonto.page/ws`
- **Transport:** WebSocket, JSON text frames
- **Protocol version:** `1`
- **Times:** milliseconds since the Unix epoch

```
1. JOIN (app -> relay)

   {"type":"join","protocol":1,"device_id":"<unique id>","name":"Sawaira"}
   Relay replies:
   {"type":"welcome","protocol":1,"server_time":1794839291139}
   Name: required, max 30 characters.

2. SEND A MESSAGE (app -> relay)
   {"type":"message","id":"<unique id>","sender":"Sawaira","text":"hi"}
   Text: 1 to 500 characters. The relay uses the name from join as the
   sender. It sets sent_at and expires_at (sent_at + 30000).

3. RECEIVE A MESSAGE (relay -> all joined apps, including the sender)
   {"type":"message","id":"...","sender":"Sawaira","text":"hi",
    "sent_at":1794839366594,"expires_at":1794839396594}

4. DELIVERED (relay -> sender only)
   {"type":"delivered","id":"...","count":2}
   count = number of joined apps that received it.

5. EXPIRED (relay -> all apps, 30 seconds after sent_at)
   {"type":"expired","id":"..."}
   Apps remove the message when they receive this or when expires_at passes.

6. HEARTBEAT
   App sends {"type":"ping"} every 15 seconds.
   Relay replies {"type":"pong"}.
   If no pong arrives for 30 seconds, the app closes the socket and reconnects.

7. RECONNECT
   Wait 1, 2, 4, then 8 seconds between attempts (8 seconds after that).
   After rejoining, the relay replays nothing.

8. DUPLICATES
   The relay ignores a message id it still holds.
   Apps keep a set of ids they have seen and ignore repeats.

9. CLOCKS
   On welcome, the app computes offset = server_time - phone_time.
   Countdown = (expires_at - offset) - phone_time.
   Phone clocks never decide when a message expires.

10. ERRORS
    {"type":"error","code":"...","message":"..."}
    Codes: bad_json, bad_protocol, bad_name, not_joined, bad_message,
    unknown_type

11. STORAGE
    The relay keeps messages in memory only and deletes them at expires_at.

12. PRESENCE (relay -> all joined apps)

    {"type":"presence","count":3,"members":["Sawaira","Ali","Sara"]}

    Sent whenever someone joins or leaves.
    members is in join order.
    Apps that do not know this type can ignore it.
 ```

## Notes

- `device_id` is sent by apps but the relay does not use it yet.
- Offline messages are queued by the app. Any message that passes 30 seconds
  before it can be sent is dropped and never sent. The relay does not know
  about the queue.
- The relay has no password. Anyone who has the address can join.
- The free host sleeps when idle, so the first connection after a pause can
  take up to a minute.