# SporTrivia SDK — Partner Setup Guide

This document is for licensed partners integrating the SporTrivia SDK into their own apps. You should have received:
- A unique **Access Key ID** (e.g., `AKIAXXXXXXXXXXXXXXXX`)
- A unique **Secret Access Key**
- A **region** (typically `us-east-2`)

These credentials are issued by the SporTrivia team and scoped to the paths the SDK needs. If your license is revoked, the credentials will stop working immediately.

---

## iOS Setup

### 1. Add the SDK via Swift Package Manager

In Xcode: `File → Add Package Dependencies…` and enter:

```
https://github.com/dornanchris/SporTriviaSDK.git
```

Pin to the desired version tag (e.g. `1.0.0`).

### 2. Add your credentials plist

Create `SporTrivia.plist` in your app bundle with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>SporTriviaAccessKey</key>
    <string>AKIAXXXXXXXXXXXXXXXX</string>
    <key>SporTriviaSecretKey</key>
    <string>your-secret-key-here</string>
    <key>SporTriviaRegion</key>
    <string>us-east-2</string>
</dict>
</plist>
```

### 3. Configure the SDK at app launch

```swift
import SporTriviaSDK

// In your App or AppDelegate
let credentials = try SporTriviaCredentials.fromPlist()
SporTriviaSDK.configure(SporTriviaConfiguration(credentials: credentials))
```

### 4. Launch a game

```swift
let gameView = SporTriviaSDK.customGameView(
    gameId: "NYI_Top5A",
    sport: .nhl,
    delegate: self
)
// Present gameView full screen (recommended): .fullScreenCover(...). The
// flow has its own exit button with confirmation, and swipe-to-dismiss is
// disabled if you present it as a sheet.
```

---

## Android Setup

### 1. Add the SDK via Gradle

```groovy
// settings.gradle
dependencyResolutionManagement {
    repositories {
        maven { url 'https://jitpack.io' }
    }
}

// app/build.gradle
dependencies {
    implementation 'com.github.dornanchris:SporTriviaSDK-android:<version>'
}
```

### 2. Add your credentials file

Create `app/src/main/assets/sportrivia.properties`:

```properties
sportrivia.accessKey=AKIAXXXXXXXXXXXXXXXX
sportrivia.secretKey=your-secret-key-here
sportrivia.region=us-east-2
```

### 3. Configure the SDK at app launch

```java
SporTriviaCredentials creds = SporTriviaCredentials.fromAssets(
    getApplicationContext(), "sportrivia.properties"
);
SporTriviaSDK.configure(
    new SporTriviaConfiguration.Builder(creds).build()
);
```

### 4. Launch a game

```java
SporTriviaSDK.launchCustomGame(context, "NYI_Top5A", Sport.NHL, delegate);
```

---

## Sponsorships

Questions can carry a sponsorship chosen on the portal's Sponsorships page. The answer key JSON embeds a `sponsorship` object (brand, click-through `url`, and the banner's S3 `asset_key`); the SDK downloads the banner and shows it as a tappable strip on the game and game-over screens automatically. Questions without a sponsorship show no banner, as do legacy answer keys — nothing to configure in your app. Note the IAM policy below includes `sponsorships/*` read access; partner credentials issued before this feature need that added.

---

## Fan Data Capture

The player-info screen the SDK shows before a game is driven by the question's **Data Capture** step in the SporTrivia portal — nothing to configure in your app. The answer key JSON carries a `collect_fields` object (standard name/email/phone toggles, an over-18 checkbox, and any custom questions with their own required flags), the SDK builds the form from it dynamically, and the collected answers are uploaded to S3 with the game results (`custom_field_answers`, keyed by question label). If a question collects nothing, the screen is skipped entirely. Answer keys created before this feature show the original name/email/phone form. The same data is available in your `SporTriviaDelegate` completion callback via `SporTriviaUserInfo` (`over18`, `customFieldAnswers`).

---

## Game Result Uploads (schema v2)

When a game ends the SDK uploads one JSON document to S3 (to the folder named
by the answer key's `response_path`). **iOS and Android emit exactly the same
fields in exactly the same order**, so partner pipelines can parse either
platform identically. Branch on `schema_version` if you also process
pre-v2 records.

| # | Field | Type | Notes |
|---|---|---|---|
| 1 | `schema_version` | int | `2` |
| 2 | `game_id` | string | The question's game identifier |
| 3 | `submitted_at` | string | UTC, `yyyy-MM-ddTHH:mm:ssZ` |
| 4 | `platform` | string | `"ios"` or `"android"` (`"web"` for portal plays) |
| 5 | `source` | string | `"sdk"` (partner apps) or `"app"` (first-party apps) |
| 6 | `sdk_version` | string \| null | SDK release, null from first-party apps |
| 7 | `first_name` | string | Empty string when the fan declined |
| 8 | `last_name` | string | Empty string when the fan declined |
| 9 | `name` | string | first + last joined |
| 10 | `email` | string | Empty string when declined |
| 11 | `phone` | string | Empty string when declined |
| 12 | `over_18` | bool | false when not asked |
| 13 | `custom_field_answers` | object | Keyed by question label, keys sorted alphabetically |
| 14 | `answers_found` | array[string] | `"Player Name years"` in guess order |
| 15 | `correct_answers` | array[object] | `{player_id, player_name, years_played}` |
| 16 | `location` | object \| null | `{latitude, longitude, accuracy_meters, captured_at}`; null unless granted |
| 17 | `location_status` | string | `granted` / `denied` / `unavailable` / `timeout` |

Sample:

```json
{"schema_version":2,"game_id":"NYY_NYM","submitted_at":"2026-07-05T18:00:00Z",
 "platform":"ios","source":"sdk","sdk_version":"1.1.0",
 "first_name":"Jane","last_name":"Smith","name":"Jane Smith",
 "email":"jane@example.com","phone":"555-0100","over_18":true,
 "custom_field_answers":{"How often do you attend games?":"Weekly"},
 "answers_found":["Player One 2000-2010"],
 "correct_answers":[{"player_id":"p1","player_name":"Player One","years_played":"2000-2010"}],
 "location":{"latitude":40.75,"longitude":-73.99,"accuracy_meters":12.5,"captured_at":"2026-07-05T17:59:58Z"},
 "location_status":"granted"}
```

**Changes from v1** (records without `schema_version`): `gameId` → `game_id`;
the duplicate `firstName`/`lastName`/`phoneNumber` keys are gone (use
`first_name`/`last_name`/`phone`); `correctAnswers` → `correct_answers` with
snake_case inner keys; `platform`/`source`/`sdk_version`/`location`/
`location_status` are new; key order is now guaranteed.

---

## Location Capture

The SDK includes the fan's device location with game-result uploads
(`location` + `location_status` above). It is strictly **best-effort**: the
game and the upload always proceed, with `location: null` and an explanatory
status, when the fan declines, the fix times out (~8s max wait at upload
time), or location services are off.

**Prompt timing:** the OS permission dialog ("while using the app") appears
over the SDK's player-info screen when a game opens, and a GPS fix starts
warming immediately so it's usually ready before the game ends.

### iOS partners

Add the usage string to your app's Info.plist — without it the OS silently
ignores the request, the SDK logs one warning, and uploads carry
`location_status: "unavailable"`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is included with your trivia answers to help teams understand where their fans are playing from.</string>
```

Update your App Store **App Privacy** answers to declare location collection.

### Android partners

The SDK library manifest declares `ACCESS_FINE_LOCATION` and
`ACCESS_COARSE_LOCATION`; manifest merging adds them to your app
automatically (no Play Services dependency — the SDK uses the framework
`LocationManager`). Declare location collection in your Play Console
**Data safety** form.

To ship without location entirely, strip the permissions in your app
manifest — the SDK then uploads `location_status: "unavailable"`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" tools:node="remove" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" tools:node="remove" />
```

---

## Deep Linking & QR Codes

Questions built in the SporTrivia portal with the **"Your own app"** destination produce a scannable QR code that launches the SDK inside your app. The flow:

1. The QR encodes a SporTrivia-hosted redirect URL (e.g. `https://<sportrivia-host>/sdk/r/<question-id>`) that always carries the information identifying the question.
2. When scanned, the page immediately attempts your deep link — your URL scheme wrapped around the SporTrivia game info:

   ```
   yourscheme://sportrivia/custom/<gameId>?info=<sportCode>
   ```

3. If your app is installed, it opens and you hand the URL to the SDK. If not, the page (branded for your team) detects iOS or Android, saves the game info so your app can claim it after install, and redirects the fan to your App Store / Google Play listing.

To enable this, save your **URL scheme**, **Android package name**, and **store URLs** on the portal's **Developer → Deep Linking & QR** tab. That unlocks the "Your own app" destination on the question setup page.

### iOS: register your URL scheme in Info.plist

In Xcode, select your project in the Project navigator, choose your app target, and open the **Info** tab. Under **URL Types**, click **+** and enter your scheme. Or right-click `Info.plist` → *Open As* → *Source Code* and add:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.yourapp.sportrivia</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourscheme</string>
        </array>
    </dict>
</array>
```

### iOS: handle the incoming URL

Use `SporTriviaDeepLink` to parse the link, then present the game view.

SwiftUI:

```swift
.onOpenURL { url in
    guard let link = SporTriviaDeepLink.parse(url) else { return }
    let gameView = SporTriviaSDK.customGameView(
        gameId: link.gameId,
        sport: link.sport,
        delegate: self
    )
    // Present gameView full screen (recommended): .fullScreenCover(...). The
// flow has its own exit button with confirmation, and swipe-to-dismiss is
// disabled if you present it as a sheet.
}
```

UIKit (AppDelegate):

```swift
func application(_ app: UIApplication,
                 open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    guard let link = SporTriviaDeepLink.parse(url) else { return false }
    let gameView = SporTriviaSDK.customGameView(gameId: link.gameId, sport: link.sport)
    // Wrap in UIHostingController and present it.
    return true
}
```

### Android: register your URL scheme in AndroidManifest.xml

Add an intent filter to the activity that should receive the QR launch (`android:exported="true"` is required on Android 12+):

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTask">

    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="yourscheme" android:host="sportrivia" />
    </intent-filter>
</activity>
```

### Android: handle the incoming intent

```java
@Override
protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    handleSporTriviaLink(getIntent());
}

@Override
protected void onNewIntent(Intent intent) {
    super.onNewIntent(intent);
    handleSporTriviaLink(intent);
}

private void handleSporTriviaLink(Intent intent) {
    SporTriviaDeepLink link = SporTriviaDeepLink.parse(intent.getData());
    if (link != null) {
        SporTriviaSDK.launchCustomGame(this, link.getGameId(), link.getSport(), myDelegate);
    }
}
```

### Optional: verified links for direct launch (Universal Links / App Links)

The scheme setup above goes through a brief hosted redirect page. If you also save your **Apple Team ID + bundle ID** and **Android signing-cert SHA-256 fingerprint** on the portal's Developer → Deep Linking & QR tab, the SporTrivia site lists your app in its `apple-app-site-association` / `assetlinks.json` files, and QR scans open your app *directly* — the browser never appears. The QR's https URL carries the same game info as a query string:

```
https://<sportrivia-host>/sdk/r/<your-team>/<question-id>?game=<gameId>&info=<sportCode>
```

`SporTriviaDeepLink.parse` understands this form too, so your existing handler code works unchanged. The redirect page and store fallback remain in place for devices without the app — verified links are purely an upgrade layer.

**iOS:** add the Associated Domains capability (Signing & Capabilities → + Capability):

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:YOUR-SPORTRIVIA-HOST</string>
</array>
```

SwiftUI's `onOpenURL` receives Universal Links. UIKit apps should also implement:

```swift
func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    guard let url = userActivity.webpageURL,
          let link = SporTriviaDeepLink.parse(url) else { return false }
    // Present SporTriviaSDK.customGameView(gameId: link.gameId, sport: link.sport)
    return true
}
```

**Android:** add a second, auto-verified intent filter next to your scheme filter (the exact host and path prefix are shown pre-filled on the portal's Developer page):

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https"
          android:host="YOUR-SPORTRIVIA-HOST"
          android:pathPrefix="/sdk/r/your-team" />
</intent-filter>
```

---

## Security: IAM Policy (for SporTrivia admins)

When provisioning a new partner, create an IAM user with the following policy. This limits what the partner's credentials can do in your S3 bucket.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadSDKData",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": [
        "arn:aws:s3:::sportrivia/answer_keys/custom/*",
        "arn:aws:s3:::sportrivia/answer_keys/*/all_*_players.json",
        "arn:aws:s3:::sportrivia/team_images/*",
        "arn:aws:s3:::sportrivia/sponsorships/*"
      ]
    },
    {
      "Sid": "WriteGameResults",
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::sportrivia/custom/*"
    }
  ]
}
```

### What this policy allows

| Operation | Path | Why |
|---|---|---|
| Read | `answer_keys/custom/*` | Load custom game answer keys |
| Read | `answer_keys/*/all_*_players.json` | Load player autocomplete lists |
| Read | `team_images/*` | Load team logos |
| Read | `sponsorships/*` | Load sponsorship banner images |
| Write | `custom/*` | Upload game results (user scores) |

> **Existing partners:** IAM users provisioned before the sponsorship feature are missing the
> `sponsorships/*` grant, so banners silently fail to load with a 403. Re-apply the policy above,
> or run `aws/update_sdk_iam_policy.py` (in the SporTrivia repo) — it idempotently adds the
> missing grant to every IAM user carrying the `SporTriviaSDKAccess` inline policy.

### What this policy denies (implicitly)

- Listing the bucket (can't enumerate your data)
- Reading anything outside the SDK paths (e.g., no access to `data_pipeline/`, `DataScrapes/`)
- Deleting any objects
- Modifying bucket policies or ACLs
- Accessing any other S3 buckets in your account

### Revoking a partner

To shut off a partner's access instantly:

1. AWS Console → IAM → Users → select the partner's IAM user
2. Security credentials → deactivate or delete the access key

Their app will fail on the next S3 request (within seconds). No code changes needed on your end or theirs.

### Recommended operational practices

- **One IAM user per partner** — never share keys between partners
- **Rotate keys periodically** (e.g., annually) by creating a new access key, updating the partner's config, then deleting the old one
- **Monitor CloudTrail** for unexpected access patterns (e.g., partner trying to access other paths and getting 403s)
- **Set S3 access logging** on the `sportrivia` bucket to audit who's reading what
- **Consider billing alerts** — if a partner's usage spikes unexpectedly, it may indicate abuse or a bug

---

## Understanding what partners see

Partner credentials are present in the app's bundle (plist on iOS, assets on Android), which means they're recoverable from the compiled app. This is acceptable because:

1. **The IAM policy is the real boundary** — even with the keys, an attacker can only access the scoped paths
2. **Revocation is instant** — revoke the IAM user, the keys are dead
3. **You own the data** — copying the SDK is useless without access to the bucket, and you control that access
4. **Presigned URLs expire in 5 minutes** — limits the damage window if a URL is intercepted

This matches how most mobile SDKs work (Stripe publishable keys, Firebase API keys, Mapbox tokens, etc.) — the keys are semi-public, but the server-side policy defines the real security boundary.
