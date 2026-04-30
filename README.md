# Morning Spotify Alarm

Personal iOS app that lets Shortcuts trigger exact Spotify playlist playback on the iPhone at alarm time.

## Architecture

The app is a Spotify playback orchestrator, not the primary alarm trigger:

1. Shortcuts Personal Automation fires at the selected time.
2. Shortcuts sets iPhone media volume to 0%.
3. Shortcuts opens Spotify and starts any playback briefly to prewarm Spotify Connect.
4. Shortcuts waits about 8 seconds, then sets iPhone media volume to the target alarm level.
5. Shortcuts runs the App Intent `Start Morning Spotify Alarm`.
6. The app refreshes the Spotify token.
7. The app calls `GET /v1/me/player/devices` with a short retry window.
8. The app selects only the saved or confidently matched unrestricted iPhone device.
9. The app calls `PUT /v1/me/player` with `play=false`, then verifies the active device.
10. The app calls `PUT /v1/me/player/play?device_id=...` with:

```json
{
  "context_uri": "spotify:playlist:3EYSOl9YotgAxH92H2nhYe"
}
```

11. The app verifies playback and logs the result.

The app does not use private iOS volume APIs, media-remote tricks, hidden volume hacks, or unsupported background keepalive behavior. Spotify volume control is skipped for iPhone devices that report `supports_volume: false`. If the target iPhone is not visible and verified, the app fails closed and does not play on a TV, speaker, desktop, web player, or Chromecast.

## Spotify Developer Setup

1. Open the Spotify Developer Dashboard.
2. Create an app.
3. Add this redirect URI:

```text
morningspotifyalarm://callback
```

4. Confirm the client ID in `MorningSpotifyAlarm/App/AppConfig.swift`.
5. Do not add a client secret to the iOS app.
6. Required scopes:

```text
user-modify-playback-state
user-read-playback-state
user-read-currently-playing
playlist-read-private
playlist-read-collaborative
```

The current default Client ID is configured in source. Any client secret or test tokens exposed during manual testing should be rotated in Spotify Developer Dashboard.

### Fix `redirect_uri: Not matching configuration`

Spotify requires an exact redirect URI match. If Safari or the Spotify login screen shows:

```text
redirect_uri: Not matching configuration
```

open the Spotify Developer Dashboard for the app with Client ID `569bdbf9ce1b47fd87da2adc41793143`, then add and save exactly:

```text
morningspotifyalarm://callback
```

Do not use `http://127.0.0.1:8888/callback` for the iPhone app flow. Do not add a trailing slash.

In the iOS app, use `Reconnect / Switch Account` on the Spotify Connection screen to clear local tokens and start a private authentication session that does not reuse the wrong Safari Spotify account.

## Running On iPhone

1. Open `MorningSpotifyAlarm.xcodeproj`.
2. Select the `MorningSpotifyAlarm` scheme.
3. Select your iPhone.
4. Build and run.
5. In the app, connect Spotify.
6. Confirm the playlist or paste a new Spotify playlist URL/URI.
7. Run `Test Now` while Spotify is open or recently active on the iPhone.

## Shortcut Automation

Create a Personal Automation:

- Automation: Time of Day
- Repeat on selected days
- Run Immediately
- Optional Action 1: Run App Shortcut: `Mark Spotify Prewarm Started`
- Action 2: Set Volume to 0%
- Action 3: Open App: Spotify
- Action 4: Play media / resume playback in Spotify, or use any reliable Siri/Spotify action that starts Spotify playback
- Action 5: Wait 8 seconds
- Action 6: Set Volume to target level, for example 70%
- Action 7: Run App Shortcut: `Start Morning Spotify Alarm`

The first Spotify playback is only a silent prewarm. The real alarm playlist is selected later by the app through Spotify Web API, always with an explicit `device_id`.

## Backup Alarm

AlarmKit support is included as a backup layer on iOS 26+. Treat it as a safety fallback, not the Spotify trigger. Also consider creating a regular iOS Clock alarm 2 minutes after the Spotify alarm.

## Overnight Reliability Checklist

Record each result in the app logs:

1. iPhone unlocked, Spotify open, run Test Now.
2. iPhone locked, Spotify in background, run Shortcut manually.
3. iPhone locked, volume set to 0, automation scheduled 2 minutes ahead.
4. iPhone locked overnight, automation scheduled for real wake-up time.
5. Wi-Fi off, cellular only.
6. Spotify force-closed before sleeping.
7. Access token expired before alarm; verify refresh token works.
