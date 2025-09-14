# 📱 iOS App Configuration for Deployed Server

After you deploy your server to Vercel, you'll get a URL like `https://ai-hackathon-xyz.vercel.app`

## Update iOS App Configuration:

1. **Open your iOS project in Xcode**

2. **Update Config.Development.plist**:
   - Navigate to `/SpendConscience/Config.Development.plist`
   - Change the `SpendConscienceAPIURL` value from the placeholder to your actual Vercel URL
   
   ```xml
   <key>SpendConscienceAPIURL</key>
   <string>https://your-actual-vercel-url.vercel.app</string>
   ```

3. **Build and test your iOS app**:
   - The app will now connect to your deployed server instead of localhost
   - Test the "🤖 Ask AI Financial Team" feature
   - Verify the health check and API responses

## Example Configuration:
If your Vercel URL is `https://spendconscience-demo.vercel.app`, then update:

```xml
<key>SpendConscienceAPIURL</key>
<string>https://spendconscience-demo.vercel.app</string>
```

## Testing:
- iOS app → Deployed Vercel server → AI agents → Mock Plaid data
- Complete end-to-end workflow ready for hackathon demo! 🚀