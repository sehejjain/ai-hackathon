# 🔒 Configuration Setup

## Setting Up API Keys

1. **Copy template files**:
   ```bash
   cp Config.Development.plist.template Config.Development.plist
   cp SpendConscience/Config.Development.plist.template SpendConscience/Config.Development.plist
   ```

2. **Get your Plaid API credentials**:
   - Sign up at [Plaid Dashboard](https://dashboard.plaid.com/)
   - Create a new app
   - Copy your Client ID and Secret (use Sandbox secret for testing)

3. **Update the plist files (development only)**:
   - Update `SpendConscienceAPIURL` with your deployed server URL
   - The Plaid credentials are now stored server-side for security

## Important Security Notes

⚠️ **Plaid credentials are handled server-side only!**
- Client apps receive only ephemeral link_tokens from the backend
- No Plaid secrets are stored in iOS app configuration
- The backend handles all Plaid API communication securely

⚠️ **Never commit actual API keys to git!**
- The `.gitignore` is configured to exclude `*.plist` files
- Only commit the `.template` files
- Keep your actual config files local only

## Deployment

For deployment, use environment variables instead of plist files:
- `PLAID_CLIENT_ID`
- `PLAID_SECRET`
- `PLAID_ENVIRONMENT=sandbox`

See `VERCEL_DEPLOYMENT.md` for deployment instructions.