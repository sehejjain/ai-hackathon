import express from 'express';
import cors from 'cors';
import { spendingGraph } from './src/spendconscience/spending.graph.js';

const app = express();
app.use(cors());
app.use(express.json());

// Initialize the spending graph
let graphInitialized = false;

const initializeGraph = async () => {
  if (!graphInitialized) {
    try {
      console.log('🔧 Initializing SpendConscience agent graph...');
      
      // Set configuration for local development
      spendingGraph.setConfig(
        'spendconscience',  // tenantId
        'default',         // projectId  
        'http://localhost:3002' // apiUrl
      );
      
      // Initialize the graph (this registers agents with the backend)
      await spendingGraph.init();
      graphInitialized = true;
      console.log('✅ Agent graph initialized successfully');
    } catch (error) {
      console.error('❌ Failed to initialize agent graph:', error);
      // For demo purposes, continue even if backend fails
      graphInitialized = true;
    }
  }
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'SpendConscience Ask API',
    graphInitialized,
    timestamp: new Date().toISOString()
  });
});

// Main /ask endpoint for financial questions
app.post('/ask', async (req, res) => {
  try {
    const { userId, query, context } = req.body;
    
    if (!query) {
      return res.status(400).json({
        error: 'Query is required',
        example: { userId: 'demo-user', query: 'Can I afford a $50 dinner tonight?' }
      });
    }
    
    // Ensure graph is initialized
    await initializeGraph();
    
    console.log(`💬 Processing query for user ${userId}: "${query}"`);
    
    // Prepare the message for the agent
    const userMessage = userId 
      ? `User ${userId} asks: ${query}` 
      : `User asks: ${query}`;
    
    try {
      // Use the spending graph to generate a response
      const response = await spendingGraph.generate(userMessage, {
        maxTurns: 5,
        maxSteps: 10,
        temperature: 0.7,
        resourceId: userId || 'anonymous',
      });
      
      res.json({
        success: true,
        data: {
          query,
          userId: userId || 'anonymous',
          response,
          timestamp: new Date().toISOString(),
          agent: 'SpendConscience Assistant'
        }
      });
      
    } catch (graphError) {
      console.error('❌ Agent graph error:', graphError);
      
      // Fallback response for demo
      const fallbackResponse = generateFallbackResponse(query);
      
      res.json({
        success: true,
        data: {
          query,
          userId: userId || 'anonymous',
          response: fallbackResponse,
          timestamp: new Date().toISOString(),
          agent: 'SpendConscience Assistant (Fallback)',
          note: 'Using fallback response due to agent initialization issues'
        }
      });
    }
    
  } catch (error) {
    console.error('❌ API Error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// Demo endpoint to test agent capabilities 
app.get('/demo', async (req, res) => {
  await initializeGraph();
  
  const demoQueries = [
    "Can I afford a $50 dinner tonight?",
    "How am I doing with my budget this month?", 
    "Should I buy that $200 gadget I've been wanting?",
    "What are my upcoming expenses this week?"
  ];
  
  res.json({
    message: 'SpendConscience Demo Queries',
    usage: 'POST /ask with { "userId": "demo-user", "query": "your question" }',
    examples: demoQueries.map(query => ({
      method: 'POST',
      endpoint: '/ask',
      body: { userId: 'demo-user', query }
    })),
    agentInfo: {
      graphId: spendingGraph.getId(),
      graphName: spendingGraph.getName(),
      defaultAgent: spendingGraph.getDefaultAgent()?.getName(),
      agentCount: spendingGraph.getAgents().length,
      agents: spendingGraph.getAgents().map(agent => ({
        id: agent.getId(),
        name: agent.getName(),
        type: agent.type
      }))
    }
  });
});

// Fallback response generator for demo purposes
function generateFallbackResponse(query: string): string {
  const lowerQuery = query.toLowerCase();
  
  if (lowerQuery.includes('afford') || lowerQuery.includes('buy')) {
    return `I'd need to analyze your current budget and upcoming expenses to give you a definitive answer about affordability. Based on typical spending patterns, I'd recommend checking your discretionary spending category and ensuring you have at least 20% buffer in your monthly budget before making this purchase. Would you like me to review your recent transactions?`;
  }
  
  if (lowerQuery.includes('budget') || lowerQuery.includes('spending')) {
    return `Let me help you review your budget status. I'd typically analyze your recent transactions, compare them against your budget limits, and highlight any categories where you're approaching or exceeding limits. I'd also project your end-of-month totals based on current spending velocity. To get specific insights, I'll need access to your transaction data.`;
  }
  
  if (lowerQuery.includes('upcoming') || lowerQuery.includes('future')) {
    return `I can help you plan for upcoming expenses by reviewing your calendar events and recurring commitments. This includes subscription payments, scheduled bills, social events, and travel plans. Based on this analysis, I'll estimate your committed expenses and help you plan accordingly.`;
  }
  
  return `I'm your SpendConscience financial assistant! I can help you with budgeting, spending analysis, affordability decisions, and financial planning. I work with a team of specialized agents to analyze your transactions, review your budgets, predict future expenses, and provide personalized financial advice. What specific financial question can I help you with?`;
}

const PORT = process.env.PORT || 4000;

app.listen(PORT, async () => {
  console.log(`🚀 SpendConscience Ask API running on port ${PORT}`);
  console.log(`📋 Demo: http://localhost:${PORT}/demo`);
  console.log(`💬 Ask endpoint: POST http://localhost:${PORT}/ask`);
  console.log(`❤️  Health: http://localhost:${PORT}/health`);
  
  // Initialize graph on startup
  await initializeGraph();
});