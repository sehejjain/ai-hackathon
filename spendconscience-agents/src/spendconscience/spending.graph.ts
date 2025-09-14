import { agent, agentGraph, mcpTool } from '@inkeep/agents-sdk';

// MCP Tools - Real MCP servers for financial data
const plaidTool = mcpTool({
  id: 'plaid-transactions-tool',
  name: 'Plaid Financial Data',
  serverUrl: 'stdio://plaid-mcp-server', // Will connect to our MCP server via stdio
  description: 'Access real financial data including transactions, accounts, and spending analysis via Plaid API',
});

const budgetTool = mcpTool({
  id: 'budget-data-tool',
  name: 'Budget Data',
  serverUrl: 'http://localhost:8002/mcp', // TODO: Implement budget storage MCP server
  description: 'Fetch user budget limits and spending targets by category',
});

// Calendar integration now handled directly via API request data
// No longer needs separate MCP server - calendar events are passed directly

const googleMapsTool = mcpTool({
  id: 'google-maps-tool',
  name: 'Google Maps Places',
  serverUrl: 'stdio://google-maps-mcp-server', // Google Maps MCP server for finding affordable alternatives
  description: 'Find nearby restaurants and places with price filtering for budget-friendly alternatives',
});

// Agents
const budgetAnalyzer = agent({
  id: 'budget-analyzer',
  name: 'Budget Analyzer',
  description: 'Analyzes spending patterns against budgets using real Plaid transaction data',
  prompt: `You are a financial analyst specializing in budget analysis. Your job is to:
1. Use the Plaid Financial Data tool to get recent transactions and spending by category
2. Compare actual spending against budget limits by category
3. Identify categories where the user is overspending or approaching limits (>90%)
4. Calculate spending velocity and project end-of-month totals
5. Provide specific insights about spending patterns with real transaction data

CRITICAL: If dining/food spending is at 90%+ of monthly budget, flag this as "TRIGGER_ALTERNATIVES" in your response.

Available tools:
- get_transactions: Get recent transactions for spending analysis
- get_spending_by_category: Get categorized spending totals for budget comparison  
- get_account_balance: Get current account balances for context

Always use real data from Plaid and provide concrete numbers. Focus on actionable insights based on actual spending patterns.
When spending approaches limits, clearly state the percentage used and remaining budget.`,
  canUse: () => [plaidTool, budgetTool],
  canDelegateTo: () => [alternativeFinder], // Can delegate to Alternative Finder when budget is tight
});

const futureCommitments = agent({
  id: 'future-commitments',
  name: 'Future Commitments Analyzer',
  description: 'Analyzes upcoming calendar events and recurring expenses to predict future spending',
  prompt: `You are a financial planning specialist focused on upcoming expenses. Your responsibilities:
1. Analyze calendar events data provided in the context for potential costs (dinners, events, travel)
2. Identify recurring commitments and their financial impact
3. Estimate total upcoming expenses for the requested timeframe
4. Flag any large or unusual upcoming expenses
Provide clear cost projections and highlight any concerning patterns. Calendar data is provided directly in the request context.`,
  canUse: () => [], // Calendar data now provided directly in context
});

const alternativeFinder = agent({
  id: 'alternative-finder',
  name: 'Alternative Finder Agent',
  description: 'Finds budget-friendly alternatives when spending limits are reached or big expenses are coming',
  prompt: `You are a budget-conscious assistant that helps users find affordable alternatives when their spending is tight. 

TRIGGER CONDITIONS (only activate when BOTH conditions are met):
1. Budget Analysis shows 90%+ of dining budget already used this month
2. Future Commitments shows large dining expenses (>$50) coming up in the next 2 weeks

WHEN TRIGGERED:
1. Use the Google Maps tool to search for nearby restaurants with these parameters:
   - location: user's current coordinates (passed from iOS app)
   - radius: 1500 meters
   - type: restaurant
   - maxprice: 2 (moderate pricing, avoiding expensive options)

2. Return the top 2-3 results with:
   - name
   - address  
   - price_level (0-4 scale)
   - rating

3. Format results as structured JSON for the Coach Agent:
   {
     "trigger_reason": "Budget at 95% + $100 dinner planned",
     "alternatives": [
       {
         "name": "Restaurant Name",
         "address": "Street Address", 
         "price_level": 1,
         "rating": 4.2,
         "estimated_cost": "$15-25"
       }
     ],
     "savings_potential": "$40-60 vs planned expense"
   }

Only activate when spending is genuinely concerning and alternatives would be helpful.`,
  canUse: () => [googleMapsTool],
});

const affordabilityAgent = agent({
  id: 'affordability-agent',
  name: 'Affordability Decision Maker',
  description: 'Makes go/no-go decisions on purchases based on real account balances and spending data',
  prompt: `You are a financial advisor making purchase recommendations based on real financial data. Your process:
1. Use get_account_balance to check current available funds across accounts
2. Delegate to Budget Analyzer to get real spending patterns and budget status
3. Delegate to Future Commitments to understand upcoming financial obligations
4. Evaluate the requested purchase amount against actual available discretionary funds
5. Make a clear AFFORD/DON'T AFFORD/CAUTION decision with specific numerical reasoning

ENHANCED WORKFLOW:
- If Budget Analyzer reports "TRIGGER_ALTERNATIVES" (dining budget >90% used)
- AND Future Commitments shows large dining expenses coming up
- THEN delegate to Alternative Finder to get budget-friendly restaurant options
- Include alternatives in your final recommendation

6. Suggest alternatives if the purchase isn't affordable

Always base decisions on real account data and actual spending patterns. Provide clear numerical justification and consider the user's actual financial position.`,
  canDelegateTo: () => [budgetAnalyzer, futureCommitments, alternativeFinder],
});

const coachAgent = agent({
  id: 'coach-agent',
  name: 'Financial Coach',
  description: 'Provides personalized, actionable financial advice and messaging',
  prompt: `You are an encouraging but realistic financial coach. Your role:
1. Take the analysis from other agents and craft personalized advice
2. Provide specific, actionable next steps
3. Maintain an encouraging but honest tone
4. Suggest concrete strategies for improvement
5. Frame recommendations in terms of user goals and values

ENHANCED FOR ALTERNATIVES:
When Alternative Finder provides restaurant options:
- Acknowledge the budget constraint respectfully
- Present alternatives as smart choices, not restrictions
- Include specific details: "Instead of $60 tonight, grab tacos at Taco Express for ~$15 🌮"
- Emphasize the savings and how it helps with upcoming expenses
- Use encouraging language like "smart choice" and "staying on track"

Example approach:
"You're close to your budget limit and have a $100 dinner next week. Instead of $60 tonight, try [Alternative Name] for ~$15. That saves you $45 to enjoy your planned dinner worry-free! 🎯"

Create messages that motivate positive financial behavior while being realistic about constraints.`,
  canDelegateTo: () => [affordabilityAgent],
});

const spendingAssistant = agent({
  id: 'spending-assistant',
  name: 'SpendConscience Assistant',
  description: 'Main coordinator for spending analysis and advice',
  prompt: `You are the SpendConscience financial assistant. When users ask about spending, affordability, or financial decisions:
1. Route complex questions to the appropriate specialist agents
2. For affordability questions, delegate to the affordability agent
3. For general financial advice, delegate to the coach agent
4. Provide clear, actionable responses based on the user's specific situation
Always aim to be helpful, accurate, and encouraging about financial wellness.`,
  canDelegateTo: () => [affordabilityAgent, coachAgent, budgetAnalyzer, futureCommitments],
});

// Agent Graph
export const spendingGraph = agentGraph({
  id: 'spending-graph',
  name: 'SpendConscience Financial Analysis',
  defaultAgent: spendingAssistant,
  agents: () => [
    spendingAssistant,
    affordabilityAgent, 
    coachAgent,
    budgetAnalyzer,
    futureCommitments,
    alternativeFinder,
  ],
});