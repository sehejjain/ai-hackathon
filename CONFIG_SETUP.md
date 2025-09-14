# 🔒 Configuration Setup

## Setting Up API Keys

1. **Copy template files**:
   ```bash
   cp Config.Development.plist.template Config.Development.plist
   cp SpendConscience/Config.Development.plist.template SpendConscience/Config.Development.plist
   ```

2. **Get your Plaid API keys**:
   - Sign up at [Plaid Dashboard](https://dashboard.plaid.com/)
   - Create a new app
   - Copy your Client ID and Sandbox API key

3. **Update the plist files**:
   - Replace `YOUR_PLAID_CLIENT_ID_HERE` with your actual Client ID
   - Replace `YOUR_PLAID_SANDBOX_API_KEY_HERE` with your actual Sandbox API key
   - Update `SpendConscienceAPIURL` with your deployed server URL

## Important Security Notes

⚠️ **Never commit actual API keys to git!**
- The `.gitignore` is configured to exclude `*.plist` files
- Only commit the `.template` files
- Keep your actual config files local only

## Deployment

For deployment, use environment variables instead of plist files:
- `PLAID_CLIENT_ID`
- `PLAID_SANDBOX_API_KEY`
- `PLAID_ENVIRONMENT=sandbox`

See `VERCEL_DEPLOYMENT.md` for deployment instructions.