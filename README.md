# SporTriviaSDK (iOS)

Swift Package for embedding SporTrivia custom games in iOS apps.

## Requirements

- iOS 16.0+
- Swift 5.9+
- A SporTrivia partner license (access key + secret key issued by the SporTrivia team)

## Installation

Add the package via Swift Package Manager.

**Xcode:** `File` → `Add Package Dependencies…` → enter:

```
https://github.com/dornanchris/SporTriviaSDK.git
```

Pin to version `1.0.0` (or later).

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/dornanchris/SporTriviaSDK.git", from: "1.0.0")
]
```

Then add `SporTriviaSDK` to your target's dependencies.

## Quick start

```swift
import SporTriviaSDK

// 1. Configure (typically in your App or AppDelegate)
let credentials = try SporTriviaCredentials.fromPlist()
SporTriviaSDK.configure(SporTriviaConfiguration(credentials: credentials))

// 2. Present the game (returns a SwiftUI View)
let gameView = SporTriviaSDK.customGameView(
    gameId: "NYI_Top5A",
    sport: .nhl,
    delegate: self
)
```

See [PARTNER_SETUP.md](PARTNER_SETUP.md) for the full integration guide, including how to add your credentials plist, IAM scoping, and the Android counterpart.

## License

This SDK is licensed for use by authorized SporTrivia partners only. See [LICENSE](LICENSE).
