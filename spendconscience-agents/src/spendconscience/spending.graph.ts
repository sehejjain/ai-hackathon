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

const calendarTool = mcpTool({
  id: 'calendar-events-tool',
  name: 'Calendar Events',
  serverUrl: 'http://localhost:8003/mcp', // TODO: Implement calendar integration MCP server
  description: 'Fetch upcoming calendar events with estimated costs for financial planning',
});

// Agents
const budgetAnalyzer = agent({
  id: 'budget-analyzer',
  name: 'Budget Analyzer',
  description: 'Analyzes spending patterns against budgets using real Plaid transaction data',
  prompt: `You are a financial analyst specializing in budget analysis. Your job is to:
1. Use the Plaid Financial Data tool to get recent transactions and spending by category
2. Compare actual spending against budget limits by category
3. Identify categories where the user is overspending or approaching limits
4. Calculate spending velocity and project end-of-month totals
5. Provide specific insights about spending patterns with real transaction data

Available tools:
- get_transactions: Get recent transactions for spending analysis
- get_spending_by_category: Get categorized spending totals for budget comparison
- get_account_balance: Get current account balances for context

Always use real data from Plaid and provide concrete numbers. Focus on actionable insights based on actual spending patterns.`,
  canUse: () => [plaidTool, budgetTool],
});

const futureCommitments = agent({
  id: 'future-commitments',
  name: 'Future Commitments Analyzer', 
  description: 'Analyzes upcoming calendar events and recurring expenses to predict future spending',
  prompt: `You are a financial planning specialist focused on upcoming expenses. Your responsibilities:
1. Review calendar events for potential costs (dinners, events, travel)
2. Identify recurring commitments and their financial impact
3. Estimate total upcoming expenses for the requested timeframe
4. Flag any large or unusual upcoming expenses
Provide clear cost projections and highlight any concerning patterns.`,
  canUse: () => [calendarTool],
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
6. Suggest alternatives if the purchase isn't affordable

Always base decisions on real account data and actual spending patterns. Provide clear numerical justification and consider the user's actual financial position.`,
  canDelegateTo: () => [budgetAnalyzer, futureCommitments],
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
  ],
});