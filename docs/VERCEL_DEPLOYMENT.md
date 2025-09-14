# 🚀 Deploy to Vercel (RECOMMENDED - Easiest & Free Forever)

## Why Vercel is Perfect for Your Hackathon:
✅ **FREE FOREVER** - No trial limits, always free for personal projects  
✅ **Zero configuration** - Your Express app works as-is  
✅ **4 hours CPU time/month** - More than enough for demos  
✅ **1M function invocations/month** - Perfect for hackathon usage  
✅ **Global CDN** - Fast responses worldwide  
✅ **No cold starts** - Always responsive  
✅ **GitHub integration** - Push to deploy automatically  

---

## Step 1: Prepare Your Code (1 minute)

Your Express server already works perfectly with Vercel! Just need to export it properly.

Update `/spendconscience-agents/plaid-integration-server.ts`:

```typescript
// ... existing code ...

// Export the Express app for Vercel (add this at the bottom)
export default app;
```

## Step 2: Deploy to Vercel (2 minutes)

### Option A: GitHub Integration (Recommended)
1. **Push your code to GitHub** (if not already done)
2. Go to [vercel.com](https://vercel.com) → Sign up with GitHub
3. Click **"New Project"** → Import your `ai-hackathon` repository
4. **Project settings**:
   - Framework Preset: `Other`
   - Root Directory: `spendconscience-agents`
   - Install Command: `pnpm install`
   - Build Command: `pnpm build`     # or `pnpm -w build` if using a workspace root
   - Output Directory: (leave empty)

5. **Environment Variables** (add these):
   ```
   NODE_ENV=production
   ENVIRONMENT=production
   PLAID_ENVIRONMENT=sandbox
   ANTHROPIC_API_KEY=your_key_here
   OPENAI_API_KEY=your_key_here
   ```

6. Click **Deploy** - Done! 🎉

### Option B: Vercel CLI (Alternative)
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy from your project directory
cd /Users/sehej/Projects/ai-hackathon/spendconscience-agents
vercel

# Follow the prompts - Vercel will auto-detect Express
```

## Step 3: Your App is Live! ✨

Your server will be available at: `https://your-project-name.vercel.app`

**Test endpoints:**
- Health: `https://your-project-name.vercel.app/health`
- Demo: `https://your-project-name.vercel.app/demo`
- API: `https://your-project-name.vercel.app/ask`

## Step 4: Update iOS App (1 minute)

Update `/SpendConscience/Config.Development.plist`:
```xml
<key>SpendConscienceAPIURL</key>
<string>https://your-project-name.vercel.app</string>
```

## Step 5: Automatic Updates 🔄

Every time you push to GitHub:
- Vercel automatically redeploys
- New URL for each branch/PR
- Instant rollbacks if needed

---

## 🎯 **Complete Hackathon Workflow**

1. **Code** → Push to GitHub
2. **Auto-deploy** → Vercel builds & deploys  
3. **Test** → Use live URL in iOS app
4. **Demo** → Share your live URL!

**Total setup time**: 5 minutes
**Cost**: $0 forever
**Maintenance**: Zero - just push code!

---

## Why Not Railway?

Railway is great, but:
- ❌ **30-day trial** then $5/month minimum
- ❌ **Pay-per-use** can be unpredictable
- ❌ **Cold starts** on free tier
- ❌ **More complex** setup

Vercel gives you:
- ✅ **Free forever** for personal projects
- ✅ **Predictable** - always free within limits
- ✅ **No cold starts** with Fluid compute
- ✅ **Simpler** - just push to deploy

---

## 🏆 Vercel = Perfect for Hackathons!

**Live in 5 minutes. Free forever. Zero maintenance.**