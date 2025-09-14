# SpendConscience - Xcode Configuration Guide

## Setting up Environment Variables for Testing

This guide will help you configure Xcode to use your Plaid API keys during testing without committing them to git.

### 1. Run the Setup Script

```bash
./setup-development.sh
```

This creates `Config.Development.xcconfig` with your environment variables.

### 2. Add Configuration Files to Xcode

1. Open `SpendConscience.xcodeproj` in Xcode
2. Right-click on your project in the navigator
3. Select "Add Files to 'SpendConscience'"
4. Add both:
   - `Config.xcconfig`
   - `Config.Development.xcconfig`

### 3. Configure Project Settings

1. Select your project in the navigator
2. Select the "SpendConscience" target
3. Go to the "Build Settings" tab
4. Search for "Configuration File"
5. Set:
   - **Debug**: `Config.Development`
   - **Release**: `Config`

### 4. Update Info.plist

Add these keys to your Info.plist:

```xml
<key>PLAID_CLIENT</key>
<string>$(PLAID_CLIENT_ID)</string>
<key>PLAID_SANDBOX_API</key>
<string>$(PLAID_SANDBOX_SECRET)</string>
```

### 5. Alternative: Environment Variables in Scheme

If the above doesn't work, you can also set environment variables directly in your test scheme:

1. In Xcode, go to Product → Scheme → Edit Scheme
2. Select "Test" on the left
3. Go to "Arguments" tab
4. Add Environment Variables:
   - `PLAID_CLIENT` = `68c5e4fe8556db00239ce996`
   - `PLAID_SANDBOX_API` = `1b2728de4c3caa8f1c7c51dbd124d6`

### 6. Update PlaidConfiguration (if needed)

Make sure your PlaidConfiguration.swift reads from environment variables:

```swift
static var secret: String? {
    // Try environment variable first (for testing)
    if let envSecret = ProcessInfo.processInfo.environment["PLAID_SANDBOX_API"] {
        return envSecret
    }
    
    // Fall back to Info.plist
    return Bundle.main.infoDictionary?["PLAID_SANDBOX_API"] as? String
}
```

### Security Notes

- `Config.Development.xcconfig` is gitignored and won't be committed
- Never commit actual API keys to your repository
- Team members will need to run `./setup-development.sh` to configure their environment

### Troubleshooting

If tests still fail to access API keys:

1. Verify environment variables are set: `echo $PLAID_CLIENT`
2. Check that Config.Development.xcconfig exists and has correct values
3. Ensure the configuration file is selected in project build settings
4. Try the scheme environment variable approach as a fallback

### Team Setup

New team members should:

1. Get Plaid API credentials
2. Add them to `~/.zshrc`:
   ```bash
   export PLAID_CLIENT="their_client_id"
   export PLAID_SANDBOX_API="their_sandbox_secret"
   ```
3. Run `source ~/.zshrc`
4. Run `./setup-development.sh`
5. Configure Xcode as described above