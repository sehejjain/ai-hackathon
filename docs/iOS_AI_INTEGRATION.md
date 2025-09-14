# SpendConscience iOS + AI Integration

This iOS app now connects to the Plaid-Inkeep integration server for intelligent financial decision making using a 4-agent AI system.

## 🏗️ Architecture

```
iOS App → SpendConscience API Server → Inkeep Agents → Plaid Data
```

### 4-Agent System
1. **Budget Analyzer** - Analyzes spending patterns against budgets
2. **Future Commitments** - Reviews upcoming expenses and financial obligations  
3. **Affordability Agent** - Makes purchase recommendations based on real data
4. **Financial Coach** - Provides personalized advice and actionable steps

## 🚀 Features

### AI Financial Assistant
- Real-time financial questions and advice
- Agent workflow visualization
- Plaid data integration showing real account balances and spending
- Quick question templates for common scenarios

### Enhanced User Experience
- **Ask AI Financial Team** button prominently featured
- Interactive chat interface with the 4-agent system
- Real-time agent flow tracking
- Financial data visualization from Plaid

## 🔧 Technical Implementation

### New Components
- `SpendConscienceAPIService.swift` - Handles communication with the AI server
- `AIFinancialAssistantView.swift` - Full-featured chat interface with agents
- Enhanced `ContentView.swift` - Prominently features AI assistant

### Configuration
- Server URL configurable via `Config.Development.plist`
- Default: `http://localhost:4001`
- Automatic connection testing and status monitoring

> Note: For simulator/device testing with `http://localhost`, add dev‑only ATS exceptions in Info.plist:
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key><true/>
</dict>
```
Prefer HTTPS in production and remove this for release builds.

### Data Models
- `SpendConscienceResponse` - API response structure
- `AgentFlowStep` - Tracks which agents participate in decisions
- `PlaidDataSummary` - Real financial data from Plaid integration

## 📱 User Journey

1. **Launch App** → "🤖 Ask AI Financial Team" prominently displayed
2. **Tap AI Button** → Full AI assistant interface opens
3. **Ask Question** → "Can I afford a $150 dinner tonight?"
4. **Agent Workflow** → See Budget Analyzer → Future Commitments → Affordability Agent → Financial Coach
5. **Get Response** → Personalized advice with real Plaid data backing the decision

## 🧪 Testing

The integration includes comprehensive testing capabilities:

### Quick Questions
- "Can I afford a $75 dinner tonight?"
- "How is my budget this month?"  
- "What are my largest expenses?"
- "Should I save more money?"
- "Can I afford a $1200 laptop?"

### Agent Flow Testing
Each question triggers the appropriate agents and shows the decision-making process in real-time.

### Plaid Data Visualization
- Account balances: $11,402.01 available
- Spending categories: Food & Drink, Transportation, etc.
- Monthly spending totals with categorization

## 🔗 Integration Status

✅ **iOS App Connected** - Native Swift integration with the AI server  
✅ **4-Agent System** - All agents working in coordination  
✅ **Plaid Data Flow** - Real financial data feeding into decisions  
✅ **Real-time Responses** - Instant AI-powered financial advice  
✅ **Agent Transparency** - Users see which agents contributed to decisions  

## 🎯 Example Interactions

**User**: "Can I afford a $150 dinner tonight?"

**Agent Flow**:
1. Budget Analyzer → Analyzed real Plaid spending data
2. Future Commitments → Reviewed upcoming expenses  
3. Affordability Agent → Made decision using real account balances
4. Financial Coach → Generated personalized advice

**Response**: "✅ Yes, you can easily afford this $150 expense! It represents only 1% of your available funds ($11,402.01)..."

## 🛠️ Development Setup

1. **Start the AI Server**:
   ```bash
   cd spendconscience-agents
   npx tsx plaid-integration-server.ts
   ```

2. **Configure iOS App**:
   - Ensure `Config.Development.plist` has `SpendConscienceAPIURL` set to `http://localhost:4001`

3. **Run iOS App**:
   - Build and run in Xcode
   - Tap "🤖 Ask AI Financial Team"
   - Test with various financial questions

The iOS app now provides a seamless interface to the powerful 4-agent AI system with real Plaid financial data integration! 🎉