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

### 5. Handle deep links (open games from the web redirect)

Games shared from the SporTrivia portal open a redirect page that deep-links into
**your** app using the scheme `sportrivia-<partnerId>` (your partner id is issued
by the SporTrivia team; set it in the portal under **Account → Partner App**).

**a. Register the URL scheme.** In your target's **Info** tab add a URL Type with
URL Scheme `sportrivia-<partnerId>` (e.g. `sportrivia-islanders`). Equivalent
`Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>sportrivia-islanders</string></array>
  </dict>
</array>
```

**b. Pass the partner id to the SDK** so it can claim games after a fresh install:

```swift
let config = SporTriviaConfiguration(
    credentials: credentials,
    partnerId: "islanders",
    redirectBaseURL: URL(string: "https://sportrivia-app.com")
)
SporTriviaSDK.configure(config)
```

**c. Handle the incoming link** (SwiftUI):

```swift
.onOpenURL { url in
    if SporTriviaSDK.handleDeepLink(url) {
        pendingGame = SporTriviaSDK.pendingGame()   // present it in your UI
    }
}
```

Then present the pending game (clearing it so it doesn't relaunch):

```swift
if let gameView = SporTriviaSDK.pendingGameView(delegate: self) {
    // present gameView
}
```

**d. Deferred deep linking (installed from the store).** For users who tap the
link, install from the App Store, then open your app for the first time, ask the
redirect service whether a game was saved off for them:

```swift
SporTriviaSDK.claimPendingGame { game in
    guard let game = game else { return }
    let view = SporTriviaSDK.customGameView(gameId: game.gameId, sport: game.sport, delegate: self)
    // present view
}
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

### 5. Handle deep links (open games from the web redirect)

Games shared from the SporTrivia portal deep-link into **your** app using the
scheme `sportrivia-<partnerId>` (issued by the SporTrivia team; set it in the
portal under **Account → Partner App**).

**a. Declare your scheme** via a manifest placeholder in your app `build.gradle`:

```groovy
android {
    defaultConfig {
        manifestPlaceholders = [sporTriviaScheme: "sportrivia-islanders"]
    }
}
```

The SDK ships an exported `SporTriviaDeepLinkActivity` with an intent-filter for
`${sporTriviaScheme}://game`, so no extra manifest entry is required — the game
launches automatically when the link is opened.

**b. Configure the SDK** with your partner id (and a default delegate to receive
results from deep-linked games):

```java
SporTriviaSDK.configure(
    new SporTriviaConfiguration.Builder(creds)
        .partnerId("islanders")
        .redirectBaseUrl("https://sportrivia-app.com")
        .defaultDelegate(myDelegate)
        .build()
);
```

**c. (Optional) Handle the link yourself** instead of the bundled activity — add
an intent-filter to your own activity and call:

```java
Uri data = getIntent().getData();
SporTriviaSDK.handleDeepLink(this, data, myDelegate);
```

**d. Deferred deep linking (installed from Google Play).** On first launch, ask
the redirect service for a game saved off before install:

```java
SporTriviaSDK.claimPendingGame(context, game -> {
    if (game != null) {
        SporTriviaSDK.launchCustomGame(context, game.getGameId(), game.getSport(), myDelegate);
    }
});
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
