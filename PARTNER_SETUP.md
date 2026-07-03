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
// Present gameView in a sheet, navigation stack, etc.
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
    // Present gameView in a sheet, navigation stack, etc.
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
        "arn:aws:s3:::sportrivia/team_images/*"
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
| Write | `custom/*` | Upload game results (user scores) |

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
