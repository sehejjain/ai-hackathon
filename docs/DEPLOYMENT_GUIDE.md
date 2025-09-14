# 🚀 SpendConscience Deployment Guide

## Quick Deployment Summary

**Recommended Platform**: Railway.app (30-day free trial + $1/month free credits after)
**Estimated Monthly Cost**: $0-3 for hackathon usage
**Deployment Time**: 5-10 minutes

---

## Option 1: Railway (RECOMMENDED) 🥇

### Why Railway?
- ✅ 30-day free trial with $5 credits
- ✅ After trial: $1/month free credits (enough for hackathon demos)
- ✅ Pay-per-second usage model
- ✅ Easy Node.js/TypeScript deployment
- ✅ Automatic HTTPS and custom domains
- ✅ GitHub integration with auto-deploys

### Step-by-Step Railway Deployment:

#### 1. Prepare Your Repository
```bash
cd /Users/sehej/Projects/ai-hackathon/spendconscience-agents
```

#### 2. Sign Up for Railway
1. Go to [railway.app](https://railway.app)
2. Click "Start Deploying"
3. Sign up with GitHub (recommended for auto-deploys)
4. Start your 30-day free trial

#### 3. Deploy from GitHub
1. In Railway dashboard, click "New Project"
2. Select "Deploy from GitHub repo"
3. Choose your `ai-hackathon` repository
4. Select the `spendconscience-agents` folder as the build path

#### 4. Configure Environment Variables
In Railway dashboard > Settings > Variables, add:
```env
NODE_ENV=production
PORT=4001
ENVIRONMENT=production
PLAID_ENVIRONMENT=sandbox
ANTHROPIC_API_KEY=your_key_here
OPENAI_API_KEY=your_key_here
PLAID_CLIENT_ID=your_client_id
PLAID_SECRET=your_secret
```

#### 5. Set Build Configuration
In Railway dashboard > Settings > Build:
- **Build Command**: `pnpm install`
- **Start Command**: `npx tsx plaid-integration-server.ts`
- **Root Directory**: `/spendconscience-agents`

#### 6. Deploy & Test
- Railway will auto-deploy from your GitHub commits
- Your app will be available at: `https://your-app-name.railway.app`
- Test health endpoint: `https://your-app-name.railway.app/health`

---

## Option 2: Render 🥈

### Why Render?
- ✅ Completely free tier (no trial limits)
- ✅ 512 MB RAM, 0.1 CPU (sufficient for demos)
- ✅ 500 build minutes/month
- ✅ 100 GB bandwidth/month
- ⚠️ Cold starts (takes ~30 seconds to wake up after inactivity)

### Step-by-Step Render Deployment:

#### 1. Sign Up for Render
1. Go to [render.com](https://render.com)
2. Sign up with GitHub

#### 2. Create New Web Service
1. Click "New +" → "Web Service"
2. Connect your GitHub repository
3. Select `ai-hackathon` repo

#### 3. Configure Service
- **Name**: `spendconscience-demo`
- **Environment**: `Node`
- **Region**: `US East (Ohio)` (closest to most users)
- **Branch**: `main` or your current branch
- **Root Directory**: `spendconscience-agents`
- **Build Command**: `pnpm install`
- **Start Command**: `npx tsx plaid-integration-server.ts`

#### 4. Set Environment Variables
Add these in Render dashboard > Environment:
```env
NODE_ENV=production
ENVIRONMENT=production
PLAID_ENVIRONMENT=sandbox
ANTHROPIC_API_KEY=your_key_here
OPENAI_API_KEY=your_key_here
PLAID_CLIENT_ID=your_client_id
PLAID_SECRET=your_secret
```

#### 5. Deploy
- Render will build and deploy automatically
- Your app will be at: `https://spendconscience-demo.onrender.com`

---

## Option 3: Vercel (Serverless) 🥉

### Why Vercel?
- ✅ Completely free for serverless functions
- ✅ 4 hours CPU time/month
- ✅ 1M function invocations/month
- ⚠️ Not ideal for persistent servers - better for API routes

### Quick Vercel Setup:
```bash
npm i -g vercel
cd spendconscience-agents
vercel
```

---

## Pre-Deployment Checklist ✅

Before deploying, ensure:
- [ ] Environment variables are properly set
- [ ] `package.json` has correct start script
- [ ] Server uses `process.env.PORT` for port configuration
- [ ] All dependencies are listed in `package.json`
- [ ] `.env` files are properly configured (but not committed to git)

---

## Update iOS App for Production 📱

After deployment, update your iOS app configuration:

1. Open `/SpendConscience/Config.Development.plist`
2. Update `SpendConscienceAPIURL` from `http://localhost:4001` to your deployed URL:
   ```xml
   <key>SpendConscienceAPIURL</key>
   <string>https://your-app-name.railway.app</string>
   ```

3. Rebuild and test your iOS app

---

## Cost Estimates 💰

### Railway (Recommended)
- **First 30 days**: FREE ($5 credits)
- **After trial**: ~$0-3/month for hackathon usage
- **Pay-per-second** so you only pay for actual usage

### Render
- **Always free** with limitations
- Cold starts after 30 minutes of inactivity
- Perfect for demos that don't need 24/7 uptime

### Vercel
- **Always free** for serverless functions
- Good for API endpoints, not persistent servers

---

## Troubleshooting 🔧

### Common Issues:
1. **Build failures**: Check that all dependencies are in `package.json`
2. **Environment variables**: Ensure all required vars are set in platform
3. **Port conflicts**: Make sure server uses `process.env.PORT`
4. **Module not found**: Verify build command installs dependencies

### Getting Help:
- Railway: [docs.railway.app](https://docs.railway.app)
- Render: [render.com/docs](https://render.com/docs)
- Community Discord servers for both platforms

---

## Next Steps 🎯

1. Choose your platform (Railway recommended)
2. Follow the deployment steps above
3. Update iOS app configuration
4. Test end-to-end workflow
5. Share your demo URL!

**Estimated total time**: 15-30 minutes from start to working deployment.

Good luck with your hackathon! 🚀