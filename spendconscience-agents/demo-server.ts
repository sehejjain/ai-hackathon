import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json());

// Mock agent responses for demo
const agentResponses = {
  'budget-analyzer': {
    name: 'Budget Analyzer',
    analyzeSpending: (query: string) => {
      if (query.toLowerCase().includes('budget')) {
        return {
          analysis: `Based on your current spending patterns:
• Food & Dining: $847/month (Budget: $800) - 6% over
• Entertainment: $156/month (Budget: $200) - 22% under  
• Transportation: $245/month (Budget: $300) - 18% under
• Shopping: $423/month (Budget: $400) - 6% over

Your total spending velocity suggests you'll be about $89 over budget this month if current trends continue.`,
          overspending: ['Food & Dining', 'Shopping'],
          underSpending: ['Entertainment', 'Transportation'],
          projectedOverage: 89
        };
      }
      return null;
    }
  },
  
  'future-commitments': {
    name: 'Future Commitments Analyzer', 
    analyzeCommitments: (query: string) => {
      return {
        analysis: `Upcoming commitments for the next 30 days:
• Jan 18: Dinner with friends (~$75)
• Jan 20: Concert tickets (~$120) 
• Jan 25: Monthly gym membership ($50)
• Feb 1: Rent payment ($1,200)
• Feb 3: Grocery shopping (~$100)

Total estimated upcoming expenses: $1,545
Available discretionary funds: $456`,
        upcomingExpenses: 1545,
        discretionaryFunds: 456,
        largeExpenses: ['Rent payment ($1,200)', 'Concert tickets ($120)']
      };
    }
  },

  'affordability-agent': {
    name: 'Affordability Decision Maker',
    makeDecision: (query: string, amount?: number) => {
      const extractedAmount = amount || extractAmountFromQuery(query);
      const available = 456; // discretionary funds
      
      if (extractedAmount <= available * 0.5) {
        return {
          decision: 'AFFORD',
          confidence: 0.85,
          reason: `You can afford this $${extractedAmount} purchase. It's ${Math.round(extractedAmount/available*100)}% of your available discretionary funds ($${available}), which is within a safe spending range.`,
          recommendation: 'Go ahead with this purchase, but consider if it aligns with your financial goals.'
        };
      } else if (extractedAmount <= available) {
        return {
          decision: 'CAUTION',
          confidence: 0.65,
          reason: `This $${extractedAmount} purchase would use ${Math.round(extractedAmount/available*100)}% of your discretionary funds ($${available}). Possible but risky.`,
          recommendation: 'Consider waiting until next month or look for a lower-cost alternative.'
        };
      } else {
        return {
          decision: 'DON\'T AFFORD',
          confidence: 0.90,
          reason: `This $${extractedAmount} purchase exceeds your available discretionary funds ($${available}) by $${extractedAmount - available}.`,
          recommendation: 'Save up for this purchase over the next few months, or look for budget-friendly alternatives.'
        };
      }
    }
  },

  'coach-agent': {
    name: 'Financial Coach',
    generateAdvice: (decision: any, query: string) => {
      if (decision?.decision === 'AFFORD') {
        return `Great news! 🎉 You're in a good position to make this purchase. Your spending has been disciplined this month, particularly in entertainment and transportation where you're under budget. 

💡 **Next steps:**
1. Make the purchase if it brings you joy or value
2. Consider moving some unspent budget from entertainment to savings
3. Keep monitoring your food & dining spending to stay on track

Remember: Smart spending is about alignment with your values, not just the numbers!`;
      } else if (decision?.decision === 'CAUTION') {
        return `I understand the temptation, but let's be strategic here. 🤔 This purchase is technically possible but would stretch your budget thin.

💡 **My recommendation:**
1. Wait 24-48 hours to see if you still want it (the "cooling off" period)
2. Check if there's a sale or discount coming up
3. Consider if you can reduce spending in another category this month

You're doing well overall - don't let one impulse purchase derail your progress! 💪`;
      } else {
        return `I know it's tough to hear, but this purchase would put you in a difficult spot financially. 😟 However, this doesn't mean "never" - it means "not right now."

💡 **Let's make a plan:**
1. Set up a dedicated savings goal for this item
2. Review your budget to find $50-100/month you can redirect to this goal
3. Look for ways to earn extra income or find a less expensive alternative

Your financial discipline will pay off! Every "no" now is a "yes" to your future financial freedom. 🌟`;
      }
    }
  }
};

function extractAmountFromQuery(query: string): number {
  const matches = query.match(/\$?(\d+(?:\.\d{2})?)/);
  return matches ? parseFloat(matches[1]) : 50; // default to $50 if no amount found
}

// Health check endpoint
app.get('/health', (req: any, res: any) => {
  res.json({ 
    status: 'ok', 
    service: 'SpendConscience Ask API (Demo Mode)',
    timestamp: new Date().toISOString(),
    agents: Object.keys(agentResponses)
  });
});

// Main /ask endpoint for financial questions  
app.post('/ask', async (req: any, res: any) => {
  try {
    const { userId, query, context } = req.body;
    
    if (!query) {
      return res.status(400).json({
        error: 'Query is required',
        example: { userId: 'demo-user', query: 'Can I afford a $50 dinner tonight?' }
      });
    }
    
    console.log(`💬 Processing query: "${query}"`);
    
    // Simulate agent workflow
    let response = '';
    const agentFlow = [];
    
    // Step 1: Determine which agents to consult
    if (query.toLowerCase().includes('afford') || query.toLowerCase().includes('buy')) {
      // Affordability question - full agent workflow
      
      // Budget Analyzer
      const budgetAnalysis = agentResponses['budget-analyzer'].analyzeSpending(query);
      agentFlow.push({ agent: 'Budget Analyzer', action: 'Analyzed current spending patterns' });
      
      // Future Commitments
      const commitmentAnalysis = agentResponses['future-commitments'].analyzeCommitments(query);
      agentFlow.push({ agent: 'Future Commitments', action: 'Reviewed upcoming expenses' });
      
      // Affordability Decision
      const decision = agentResponses['affordability-agent'].makeDecision(query);
      agentFlow.push({ agent: 'Affordability Agent', action: `Made decision: ${decision.decision}` });
      
      // Financial Coach
      const advice = agentResponses['coach-agent'].generateAdvice(decision, query);
      agentFlow.push({ agent: 'Financial Coach', action: 'Generated personalized advice' });
      
      response = `${decision.reason}\n\n${advice}`;
      
    } else if (query.toLowerCase().includes('budget') || query.toLowerCase().includes('spending')) {
      // Budget question - primarily budget analyzer
      const analysis = agentResponses['budget-analyzer'].analyzeSpending(query);
      const advice = agentResponses['coach-agent'].generateAdvice(null, query);
      agentFlow.push({ agent: 'Budget Analyzer', action: 'Analyzed spending vs budget' });
      agentFlow.push({ agent: 'Financial Coach', action: 'Provided budgeting advice' });
      
      response = `${analysis?.analysis}\n\n${advice}`;
      
    } else if (query.toLowerCase().includes('upcoming') || query.toLowerCase().includes('future')) {
      // Future expenses question
      const commitments = agentResponses['future-commitments'].analyzeCommitments(query);
      agentFlow.push({ agent: 'Future Commitments', action: 'Analyzed upcoming commitments' });
      
      response = commitments.analysis;
      
    } else {
      // General financial question
      response = `Hello! I'm your SpendConscience assistant. I work with a team of specialized financial agents to help you:

🔍 **Budget Analyzer** - Reviews your spending vs budgets
📅 **Future Commitments** - Plans for upcoming expenses  
💰 **Affordability Agent** - Makes purchase recommendations
🏆 **Financial Coach** - Provides personalized advice

Try asking me:
• "Can I afford a $75 dinner tonight?"
• "How am I doing with my budget this month?"
• "What are my upcoming expenses?"
• "Should I buy that $200 gadget?"`;
      
      agentFlow.push({ agent: 'SpendConscience Assistant', action: 'Provided general guidance' });
    }
    
    res.json({
      success: true,
      data: {
        query,
        userId: userId || 'demo-user',
        response,
        timestamp: new Date().toISOString(),
        agentFlow,
        mode: 'demo'
      }
    });
    
  } catch (error: any) {
    console.error('❌ API Error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// Demo endpoint
app.get('/demo', (req: any, res: any) => {
  const demoQueries = [
    "Can I afford a $50 dinner tonight?",
    "How am I doing with my budget this month?", 
    "Should I buy that $200 gadget I've been wanting?",
    "What are my upcoming expenses this week?"
  ];
  
  res.json({
    message: 'SpendConscience Demo - Multi-Agent Financial Assistant',
    usage: 'POST /ask with { "userId": "demo-user", "query": "your question" }',
    examples: demoQueries.map(query => ({
      method: 'POST',
      endpoint: '/ask',
      body: { userId: 'demo-user', query }
    })),
    agents: Object.entries(agentResponses).map(([id, agent]) => ({
      id,
      name: agent.name
    })),
    note: 'This is a demo version with mock data. The actual implementation uses Inkeep AgentGraph with real Plaid data.'
  });
});

const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log(`🚀 SpendConscience Ask API (Demo) running on port ${PORT}`);
  console.log(`📋 Demo: http://localhost:${PORT}/demo`);
  console.log(`💬 Ask endpoint: POST http://localhost:${PORT}/ask`);
  console.log(`❤️  Health: http://localhost:${PORT}/health`);
  console.log('');
  console.log('🎯 Try these queries:');
  console.log('  curl -X POST http://localhost:4000/ask -H "Content-Type: application/json" -d \'{"query": "Can I afford a $50 dinner?"}\'');
  console.log('  curl -X POST http://localhost:4000/ask -H "Content-Type: application/json" -d \'{"query": "How is my budget this month?"}\'');
});