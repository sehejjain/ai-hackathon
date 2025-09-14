# SpendConscience - Team Setup Guide

## 🚀 Quick Setup for New Developers

**For any developer joining the project, follow these simple steps:**

### 1. Get Your Plaid API Credentials
- Get your `PLAID_CLIENT` and `PLAID_SANDBOX_API` credentials
- Add them to your shell environment (`~/.zshrc` or `~/.bashrc`):

```bash
export PLAID_CLIENT="your_client_id_here"
export PLAID_SANDBOX_API="your_sandbox_secret_here"
```

### 2. Run the Setup Script
```bash
# Clone the repo and navigate to it
cd ai-hackathon

# Reload your shell environment
source ~/.zshrc

# Run the automated setup
./setup-development.sh
```

### 3. Add Files to Xcode
1. Open `SpendConscience.xcodeproj` in Xcode
2. Right-click your project → "Add Files to 'SpendConscience'"
3. Add `EnvironmentLoader.swift` to your project (if not already added)

### 4. Build and Test
```bash
# Test the setup
xcodebuild test -project SpendConscience.xcodeproj -scheme SpendConscience -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'
```

**That's it! 🎉 No manual Xcode configuration needed.**

---

## 📋 How It Works

### Environment Variable Priority (in order):
1. **`.env` file** (created by setup script) - Primary for development
2. **Environment variables** - For CI/testing environments  
3. **Info.plist** - Fallback for production builds

### Files Created by Setup Script:
- `.env` - Contains your API keys for the app to read
- `Config.Development.xcconfig` - Xcode configuration (backup method)

### Files in Git:
- ✅ `setup-development.sh` - Setup script
- ✅ `EnvironmentLoader.swift` - Code to read .env files
- ✅ `TEAM_SETUP.md` - This documentation
- ❌ `.env` - **NEVER committed** (contains secrets)
- ❌ `Config.Development.xcconfig` - **NEVER committed** (contains secrets)

---

## 🔧 Troubleshooting

### "API keys not found" Error
1. Check your environment variables: `echo $PLAID_CLIENT $PLAID_SANDBOX_API`
2. If empty, add them to your `~/.zshrc` and run `source ~/.zshrc`
3. Re-run `./setup-development.sh`
4. Rebuild the project

### Setup Script Fails
- Ensure you have the environment variables set in your shell
- Make sure the script is executable: `chmod +x setup-development.sh`
- Check that you're in the project root directory

### Still Getting Errors
1. Verify `.env` file exists and has content: `cat .env`
2. Check that `EnvironmentLoader.swift` is added to your Xcode project
3. Clean and rebuild: Product → Clean Build Folder

---

## 👥 Team Workflow

### For Existing Developers
- If you get API key errors after pulling updates, just re-run: `./setup-development.sh`

### For New Team Members
1. Get Plaid credentials from team lead
2. Follow the "Quick Setup" steps above
3. You're ready to develop!

### For CI/CD
Set environment variables `PLAID_CLIENT` and `PLAID_SANDBOX_API` in your CI system.

---

## 🔐 Security Notes

- **Never commit `.env` or `Config.Development.xcconfig`** - they contain secrets
- Each developer manages their own API credentials
- The setup script masks sensitive values in output
- All secret-containing files are gitignored

---

## 📱 What This Enables

Once set up, your app will:
- ✅ Load Plaid API keys automatically
- ✅ Initialize PlaidService successfully  
- ✅ Run tests with real API access
- ✅ Work consistently across all developer machines

No more manual Xcode scheme configuration or missing API keys! 🚀