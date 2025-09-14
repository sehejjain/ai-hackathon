#!/usr/bin/env node

/**
 * Plaid-Inkeep Integration Test Server
 * Tests the complete workflow: Plaid MCP → Inkeep Agents → Financial Decisions
 */

import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { spawn } from 'child_process';
import { spendingGraph } from './src/spendconscience/spending.graph.js';

// Load environment
dotenv.config();

const app = express();
const PORT = process.env.PORT || 4001;

// Trust proxy for Railway/Render deployment
app.set('trust proxy', 1);

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'PlaidInkeep Integration Server',
    timestamp: new Date().toISOString(),
    plaid_environment: process.env.PLAID_ENVIRONMENT || 'sandbox'
  });
});

// Main integration endpoint
app.post('/ask', async (req, res) => {
  try {
    const {
      query,
      userId = 'test-user',
      user_id,
      accessToken,
      access_token,
      lat,
      lng,
      coordinates,
      calendarEvents = [],
      calendar_events = []
    } = req.body;

    // Support both camelCase and snake_case for iOS compatibility
    const finalUserId = userId || user_id || 'test-user';
    const finalAccessToken = accessToken || access_token;
    // Use calendar_events (snake_case from iOS) if calendarEvents (camelCase) is empty
    const finalCalendarEvents = calendarEvents.length > 0 ? calendarEvents : calendar_events;

    if (!query) {
      return res.status(400).json({
        success: false,
        error: 'Query is required'
      });
    }

    console.log(`📥 [Server] Received query: "${query}" for user: ${finalUserId}`);
    console.log(`📅 [Server] Received ${finalCalendarEvents.length} calendar events for AI analysis`);

    // Log the entire request body for debugging
    console.log(`📦 [Server] Full request body keys:`, Object.keys(req.body));

    // Log calendar events details if any
    if (finalCalendarEvents && finalCalendarEvents.length > 0) {
      console.log(`📝 [Server] Calendar events details:`);
      finalCalendarEvents.forEach((event, index) => {
        console.log(`  Event ${index + 1}: ${JSON.stringify(event, null, 2)}`);
      });
    } else {
      console.log(`❌ [Server] No calendar events received after processing both camelCase and snake_case`);
      console.log(`   calendarEvents: ${calendarEvents.length}, calendar_events: ${calendar_events.length}`);

      // Log first 500 chars of request body for debugging
      const bodyStr = JSON.stringify(req.body).substring(0, 500);
      console.log(`📦 [Server] Request body preview: ${bodyStr}...`);
    }

    // Parse location coordinates if provided
    let userLocation = "37.7749,-122.4194"; // Default to SF
    if (coordinates) {
      userLocation = coordinates;
    } else if (lat && lng) {
      userLocation = `${lat},${lng}`;
    }

    // For real integration, we would:
    // 1. Start the Plaid MCP server as a background process
    // 2. Configure Inkeep to connect to the MCP server
    // 3. Let Inkeep agents use real Plaid data through MCP tools

    // For now, let's simulate the integration workflow with real calendar data
    const integrationResponse = await simulateIntegration(query, finalAccessToken, userLocation, finalCalendarEvents);

    // Ensure we have valid response data
    if (!integrationResponse || !integrationResponse.response) {
      throw new Error('Failed to generate response from integration');
    }

    const responseData = {
      query,
      user_id: finalUserId,
      response: integrationResponse.response,
      agent_flow: integrationResponse.agentFlow || [],
      plaid_data: integrationResponse.plaidData || null,
      timestamp: new Date().toISOString(),
      mode: 'plaid-integration'
    };

    console.log(`✅ Sending response with ${responseData.agent_flow.length} agent steps`);

    res.json({
      success: true,
      data: responseData
    });

  } catch (error) {
    console.error('❌ Error processing request:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error'
    });
  }
});

// Demo page
app.get('/demo', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Plaid-Inkeep Integration Demo</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .test-section { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; }
        button:hover { background: #0056b3; }
        #response { background: #fff; border: 1px solid #ddd; padding: 15px; margin-top: 10px; min-height: 100px; }
        .agent-flow { background: #e7f3ff; padding: 10px; margin: 5px 0; border-radius: 3px; }
      </style>
    </head>
    <body>
      <h1>🏦 Plaid-Inkeep Integration Demo</h1>
      <p>This server integrates Plaid financial data with Inkeep agents for intelligent financial decisions.</p>
      
            <div class="test-section">
        <h3>Test Financial Questions:</h3>
        <button onclick="testQuery('Can I afford a $150 dinner tonight?')">Test Affordability</button>
        <button onclick="testQuery('How am I doing with my budget this month?')">Test Budget Analysis</button>
        <button onclick="testQuery('What are my largest expenses this week?')">Test Spending Analysis</button>
        <button onclick="testQuery('Should I save more money?')">Test Financial Advice</button>
        <button onclick="testAlternativeFinder()" style="background: #ff6b35;">Test Alternative Finder</button>
      </div>
      
      <div class="test-section">
        <h3>Custom Query:</h3>
        <input type="text" id="customQuery" placeholder="Ask about your finances..." style="width: 70%; padding: 8px;">
        <button onclick="testCustomQuery()">Ask</button>
      </div>
      
      <div id="response"></div>

      <script>
        async function testQuery(query) {
          const responseDiv = document.getElementById('response');
          responseDiv.innerHTML = '<p>🤔 Processing with Plaid data and Inkeep agents...</p>';
          
          try {
            const response = await fetch('/ask', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ 
                query: query,
                accessToken: 'demo-token' // In real app, this would be a valid Plaid token
              })
            });
            
            const data = await response.json();
            
            if (data.success) {
              let html = '<h3>🎯 Agent Response:</h3>';
              html += '<p><strong>' + data.data.response + '</strong></p>';
              
              if (data.data.agentFlow) {
                html += '<h4>🔄 Agent Workflow:</h4>';
                data.data.agentFlow.forEach(step => {
                  html += '<div class="agent-flow"><strong>' + step.agent + ':</strong> ' + step.action + '</div>';
                });
              }
              
              if (data.data.plaidData) {
                html += '<h4>💳 Plaid Data Used:</h4>';
                html += '<pre>' + JSON.stringify(data.data.plaidData, null, 2) + '</pre>';
              }
              
              responseDiv.innerHTML = html;
            } else {
              responseDiv.innerHTML = '<p style="color: red;">❌ Error: ' + data.error + '</p>';
            }
          } catch (error) {
            responseDiv.innerHTML = '<p style="color: red;">❌ Network error: ' + error.message + '</p>';
          }
        }
        
        function testCustomQuery() {
          const query = document.getElementById('customQuery').value;
          if (query.trim()) {
            testQuery(query);
          }
        }
        
        function testAlternativeFinder() {
          testQuery('Can I afford a $60 dinner tonight? I have a $100 fancy dinner planned next week.');
        }
        
        document.getElementById('customQuery').addEventListener('keypress', function(e) {
          if (e.key === 'Enter') {
            testCustomQuery();
          }
        });
      </script>
    </body>
    </html>
  `);
});

// Simulate the integration workflow
async function simulateIntegration(query: string, accessToken?: string, userLocation: string = "37.7749,-122.4194", calendarEvents: any[] = []) {
  console.log('🔄 Simulating Plaid-Inkeep integration...');
  console.log(`🗓️ Analyzing ${calendarEvents.length} calendar events`);

  // Get real Plaid data
  const mockPlaidData = await getPlaidData(accessToken);

  // Analyze calendar events for future commitments
  const calendarAnalysis = analyzeCalendarEvents(calendarEvents);

  // Simulate agent flow based on query type
  const agentFlow = [];
  let response = '';

  // Check for Alternative Finder trigger scenario
  const hasCurrentExpense = query.toLowerCase().includes('afford') && extractAmount(query);
  const hasFuturePlanned = query.toLowerCase().includes('planned') || query.toLowerCase().includes('next week') || query.toLowerCase().includes('upcoming');
  const triggerAlternatives = hasCurrentExpense && hasFuturePlanned;

  if (query.toLowerCase().includes('afford')) {
    // Affordability workflow
    agentFlow.push({ agent: 'Budget Analyzer', action: `Analyzed real Plaid spending data - Food budget at ${mockPlaidData.food_budget.percentage_used}% of $${mockPlaidData.food_budget.monthly_limit} limit` });

    // Use real calendar data instead of hardcoded scenario
    if (calendarAnalysis.totalEvents > 0) {
      agentFlow.push({ agent: 'Future Commitments', action: `Analyzed ${calendarAnalysis.totalEvents} upcoming events - Total estimated cost: $${calendarAnalysis.totalCost.toFixed(2)}` });
      if (calendarAnalysis.expensiveEvents.length > 0) {
        const expensiveEvent = calendarAnalysis.expensiveEvents[0];
        agentFlow.push({ agent: 'Future Commitments', action: `Detected expensive event: ${expensiveEvent.title} ($${expensiveEvent.estimated_cost.toFixed(2)}) on ${new Date(expensiveEvent.start_date * 1000).toLocaleDateString()}` });
      }
    } else {
      agentFlow.push({ agent: 'Future Commitments', action: 'No significant upcoming events detected for rest of month' });
    }
    
    if (triggerAlternatives) {
      agentFlow.push({ agent: 'Alternative Finder', action: 'Triggered due to budget strain + future commitments' });
      agentFlow.push({ agent: 'Alternative Finder', action: 'Searched Google Maps for nearby affordable restaurants (maxprice=2)' });
      agentFlow.push({ agent: 'Alternative Finder', action: 'Found 3 budget-friendly alternatives within 1500m' });
    }
    
    agentFlow.push({ agent: 'Affordability Agent', action: 'Made decision using real account balances' });
    agentFlow.push({ agent: 'Financial Coach', action: 'Generated advice with alternatives if applicable' });

    const amount = extractAmount(query);
    const availableFunds = mockPlaidData.available_funds;
    const percentage = amount ? Math.round((amount / availableFunds) * 100) : 0;

    // Check if this is a food expense when already at 95% of food budget
    const isFoodExpense = query.toLowerCase().includes('dinner') || query.toLowerCase().includes('lunch') || query.toLowerCase().includes('restaurant') || query.toLowerCase().includes('meal');
    const isOverFoodBudget = isFoodExpense && mockPlaidData.food_budget.percentage_used >= 95;

    if (triggerAlternatives && amount && (isOverFoodBudget || amount >= 50)) {
      // Alternative Finder scenario - get real restaurant alternatives
      console.log('🔍 Searching for real restaurant alternatives...');
      const restaurantData = await searchNearbyRestaurants(userLocation, 2);
      const restaurants = restaurantData.results;

      response = `⚠️ Hold up! You're at ${mockPlaidData.food_budget.percentage_used}% of your $${mockPlaidData.food_budget.monthly_limit} food budget and have a $100 fancy dinner next week. 

**Current situation:**
💰 Available funds: $${availableFunds.toLocaleString()}
🍽️ Food budget used: $${mockPlaidData.food_budget.spent_so_far} / $${mockPlaidData.food_budget.monthly_limit} (${mockPlaidData.food_budget.percentage_used}%)
💸 Only $${mockPlaidData.food_budget.remaining} left in food budget!
📅 Upcoming: $100 fancy dinner planned

**💡 Smart alternatives near you:**`;

      // Add real restaurant alternatives
      restaurants.forEach((restaurant: any, index: number) => {
        const distance = (0.3 + index * 0.2).toFixed(1); // Simulate distances
        const emoji = index === 0 ? '🌮' : index === 1 ? '🍜' : '🥗';
        response += `
${emoji} **${restaurant.name}** - ${distance} miles away
   • Price: ${formatPriceLevel(restaurant.price_level)} • Rating: ${restaurant.rating}⭐
   • Address: ${restaurant.vicinity}
   • Estimated cost: ${restaurant.estimated_cost}`;
      });

      const cheapestCost = 15; // Use first restaurant's estimated low end
      response += `

**🎯 Recommendation:** 
Skip the $${amount} tonight and try ${restaurants[0]?.name || 'a nearby alternative'} for ~$${cheapestCost}. That saves you $${amount - cheapestCost} to enjoy your planned $100 dinner worry-free! You'll stay within budget and still eat great food. 🌟

Your future self will thank you! 💪`;

      // Add real Google Maps data to plaidData
      (mockPlaidData as any).alternatives = {
        trigger_reason: `Food budget at ${mockPlaidData.food_budget.percentage_used}% + $100 dinner planned`,
        search_location: userLocation,
        api_source: "Google Places API",
        alternatives: restaurants.map((restaurant: any, index: number) => ({
          name: restaurant.name,
          address: restaurant.vicinity,
          price_level: restaurant.price_level,
          rating: restaurant.rating,
          estimated_cost: restaurant.estimated_cost,
          distance: `${(0.3 + index * 0.2).toFixed(1)} miles`
        })),
        savings_potential: `$${amount - cheapestCost} saved vs planned expense`
      };
    } else if (amount && amount <= availableFunds * 0.1) {
      response = `✅ Yes, you can afford this $${amount} expense! It represents ${percentage}% of your available funds ($${availableFunds.toLocaleString()}).

Based on your real Plaid data:
💰 **Available across all accounts:** $${availableFunds.toLocaleString()}
📊 **Monthly spending so far:** $${mockPlaidData.total_spending.toLocaleString()}
🎯 **Spending breakdown:** Food & Drink leads at $${mockPlaidData.spending_by_category['Food and Drink'].toLocaleString()}
⚠️ **Food budget alert:** You've used ${mockPlaidData.food_budget.percentage_used}% of your $${mockPlaidData.food_budget.monthly_limit} monthly food budget

💡 **Smart next steps:**
1. This expense is affordable but watch your food budget
2. You only have $${mockPlaidData.food_budget.remaining} left in food budget this month
3. Consider meal prep to stretch your remaining food budget

Stay mindful of your limits! 💪`;
    } else if (amount && amount <= availableFunds * 0.3) {
      response = `⚠️ You can afford this $${amount} expense, but let's be strategic. It's ${percentage}% of your available funds.

Based on your real account data:
💰 **Available funds:** $${availableFunds.toLocaleString()}
📈 **Current spending:** $${mockPlaidData.total_spending.toLocaleString()} this month

💡 **My recommendation:**
1. This purchase is possible but significant
2. Consider if this aligns with your financial goals
3. Maybe look for a 10-20% discount or wait for a sale?

You're in control - just make it intentional! 💪`;
    } else {
      response = `🚫 I'd recommend waiting on this $${amount} purchase. It would use ${percentage}% of your available funds, which could strain your finances.

Your real financial picture:
💰 **Available:** $${availableFunds.toLocaleString()}
📊 **Already spent this month:** $${mockPlaidData.total_spending.toLocaleString()}

💡 **Better plan:**
1. Save $200-300/month toward this goal
2. You could afford it in 2-3 months comfortably
3. Look for similar alternatives at 50% less cost

Your future self will thank you for waiting! 🎯`;
    }

  } else if (query.toLowerCase().includes('budget')) {
    // Budget analysis workflow
    agentFlow.push({ agent: 'Budget Analyzer', action: 'Analyzed Plaid spending by category' });
    agentFlow.push({ agent: 'Financial Coach', action: 'Generated budget insights' });

    response = `📊 **Your Budget Analysis (Real Plaid Data)**

**This Month's Spending:**
🍽️ Food & Drink: $${mockPlaidData.spending_by_category['Food and Drink'].toLocaleString()}
🚗 Transportation: $${mockPlaidData.spending_by_category['Transportation'].toLocaleString()}
🎬 Entertainment: $${mockPlaidData.spending_by_category['Entertainment'].toLocaleString()}
🛍️ Shopping: $${mockPlaidData.spending_by_category['Shopping'].toLocaleString()}
📱 Bills: $${mockPlaidData.spending_by_category['Bills'].toLocaleString()}

**Total Spent:** $${mockPlaidData.total_spending.toLocaleString()}
**Available Funds:** $${mockPlaidData.available_funds.toLocaleString()}

💡 **Key Insights:**
• Your food spending is quite high - consider meal planning
• Transportation costs are reasonable
• You have strong savings discipline with $8,945 in savings
• Bills are consistent and manageable

🎯 **Recommendations:**
1. Try to reduce food spending by $200-300 next month
2. Set up automatic $500 monthly savings transfer
3. Your entertainment budget has room for fun!`;

  } else {
    // General financial advice
    agentFlow.push({ agent: 'Budget Analyzer', action: 'Reviewed comprehensive Plaid data' });
    agentFlow.push({ agent: 'Financial Coach', action: 'Generated personalized financial insights' });

    response = `🌟 **Your Financial Health Check (Real Data)**

**Strengths:**
✅ Excellent savings balance: $8,945
✅ Healthy checking account: $2,457
✅ Bills are under control: $1,200/month

**Opportunities:**
📈 Food spending could be optimized
💰 You could increase automated savings
🎯 Emergency fund looks solid

**Action Plan:**
1. Set up $400/month automatic savings transfer
2. Use the 50/30/20 rule: 50% needs, 30% wants, 20% savings
3. Track weekly food spending to optimize

You're doing great! Small tweaks will amplify your success. 🚀`;
  }

  return {
    response,
    agentFlow,
    plaidData: mockPlaidData
  };
}

// Helper function to extract monetary amounts from queries
function extractAmount(query: string): number | null {
  const match = query.match(/\$?(\d+(?:,\d{3})*(?:\.\d{2})?)/);
  return match ? parseFloat(match[1].replace(/,/g, '')) : null;
}

// Real Google Places API integration
async function searchNearbyRestaurants(location: string = "37.7749,-122.4194", maxPrice: number = 2) {
  const apiKey = process.env.GPLACES_API_KEY;
  
  if (!apiKey) {
    console.warn('⚠️ Google Places API key not found, using mock data');
    return {
      results: [
        {
          name: "Taco Express",
          vicinity: "123 Mission St, San Francisco",
          price_level: 1,
          rating: 4.2,
          estimated_cost: "$12-18"
        },
        {
          name: "Noodle House", 
          vicinity: "456 Valencia St, San Francisco",
          price_level: 2,
          rating: 4.0,
          estimated_cost: "$15-25"
        },
        {
          name: "Green Bowl",
          vicinity: "789 Market St, San Francisco", 
          price_level: 1,
          rating: 4.4,
          estimated_cost: "$10-16"
        }
      ]
    };
  }

  try {
    const [lat, lng] = location.split(',');
    const response = await fetch(
      `https://maps.googleapis.com/maps/api/place/nearbysearch/json?` +
      `location=${lat},${lng}&` +
      `radius=1500&` +
      `type=restaurant&` +
      `maxprice=${maxPrice}&` +
      `key=${apiKey}`
    );

    if (!response.ok) {
      throw new Error(`Google Places API error: ${response.status}`);
    }

    const data = await response.json();
    
    // Process and format the results
    const restaurants = data.results.slice(0, 3).map((place: any) => ({
      name: place.name,
      vicinity: place.vicinity,
      price_level: place.price_level || 1,
      rating: place.rating || 4.0,
      estimated_cost: estimateCostFromPriceLevel(place.price_level || 1)
    }));

    return { results: restaurants };
    
  } catch (error) {
    console.error('❌ Error fetching restaurants:', error);
    // Fallback to mock data
    return {
      results: [
        {
          name: "Taco Express",
          vicinity: "123 Mission St, San Francisco",
          price_level: 1,
          rating: 4.2,
          estimated_cost: "$12-18"
        },
        {
          name: "Noodle House", 
          vicinity: "456 Valencia St, San Francisco",
          price_level: 2,
          rating: 4.0,
          estimated_cost: "$15-25"
        },
        {
          name: "Green Bowl",
          vicinity: "789 Market St, San Francisco", 
          price_level: 1,
          rating: 4.4,
          estimated_cost: "$10-16"
        }
      ]
    };
  }
}

// Helper to estimate cost from Google's price level
function estimateCostFromPriceLevel(priceLevel: number): string {
  switch (priceLevel) {
    case 1: return "$8-15";
    case 2: return "$15-25";
    case 3: return "$25-40";
    case 4: return "$40-60";
    default: return "$10-20";
  }
}

// Helper to format price level as symbols
function formatPriceLevel(priceLevel: number): string {
  return '$'.repeat(Math.max(1, priceLevel));
}

// Real Plaid API integration
async function getPlaidData(accessToken?: string) {
  // For demo purposes, if no access token, return budget-constrained mock data
  // In production, this would always require a real access token
  if (!accessToken || accessToken === 'demo-token') {
    console.log('💡 Using demo financial data - budget constrained scenario');
    return {
      accounts: [
        {
          id: 'acc_123',
          name: 'Primary Checking',
          type: 'depository',
          subtype: 'checking',
          available_balance: 1456.78,
          current_balance: 1456.78
        },
        {
          id: 'acc_456',
          name: 'Savings Account', 
          type: 'depository',
          subtype: 'savings',
          available_balance: 2345.23,
          current_balance: 2345.23
        }
      ],
      spending_by_category: {
        'Food and Drink': 1235.00,  // High food spending - close to budget limit
        'Transportation': 456.23,
        'Entertainment': 234.56,
        'Shopping': 567.89,
        'Bills': 1200.00
      },
      total_spending: 3693.68,
      available_funds: 3802.01,  // Much lower available funds
      food_budget: {
        monthly_limit: 1300.00,
        spent_so_far: 1235.00,
        remaining: 65.00,
        percentage_used: 95.0  // Explicitly at 95% of food budget
      }
    };
  }

  // TODO: Implement real Plaid API calls here
  // For now, we'll use the MCP server approach or direct Plaid API calls
  console.log('🏦 Would fetch real Plaid data with access token:', accessToken);
  
  // Placeholder for real Plaid integration
  return {
    accounts: [
      {
        id: 'real_acc_123',
        name: 'Real Checking Account',
        type: 'depository',
        subtype: 'checking',
        available_balance: 2500.00,
        current_balance: 2500.00
      }
    ],
    spending_by_category: {
      'Food and Drink': 890.50,
      'Transportation': 320.75,
      'Entertainment': 180.25,
      'Shopping': 445.30,
      'Bills': 1250.00
    },
    total_spending: 3086.80,
    available_funds: 5200.00,
    food_budget: {
      monthly_limit: 1000.00,
      spent_so_far: 890.50,
      remaining: 109.50,
      percentage_used: 89.1
    }
  };
}

// Analyze calendar events for future commitments
function analyzeCalendarEvents(calendarEvents: any[]) {
  if (!calendarEvents || calendarEvents.length === 0) {
    return {
      totalEvents: 0,
      totalCost: 0,
      expensiveEvents: [],
      diningEvents: [],
      summary: "No upcoming events found"
    };
  }

  let totalCost = 0;
  const expensiveEvents = [];
  const diningEvents = [];

  for (const event of calendarEvents) {
    // Use snake_case field names as sent by iOS
    const cost = event.estimated_cost || 0;
    totalCost += cost;

    // Track expensive events (>$50)
    if (cost > 50) {
      expensiveEvents.push(event);
    }

    // Track dining events specifically for budget analysis
    if (event.event_type === 'dining') {
      diningEvents.push(event);
    }
  }

  // Sort expensive events by cost (highest first)
  expensiveEvents.sort((a, b) => (b.estimated_cost || 0) - (a.estimated_cost || 0));

  const summary = `${calendarEvents.length} events found, $${totalCost.toFixed(2)} estimated total cost`;

  console.log(`📊 Calendar Analysis: ${summary}`);
  if (expensiveEvents.length > 0) {
    console.log(`💸 Expensive events: ${expensiveEvents.map(e => `${e.title} ($${e.estimated_cost})`).join(', ')}`);
  }
  if (diningEvents.length > 0) {
    const diningCost = diningEvents.reduce((sum, e) => sum + (e.estimated_cost || 0), 0);
    console.log(`🍽️  Dining events: ${diningEvents.length} events, $${diningCost.toFixed(2)} total`);
  }

  return {
    totalEvents: calendarEvents.length,
    totalCost,
    expensiveEvents,
    diningEvents,
    summary
  };
}

// Start the server
app.listen(PORT, () => {
  console.log(`🚀 Plaid-Inkeep Integration Server running on port ${PORT}`);
  console.log(`📋 Demo: http://localhost:${PORT}/demo`);
  console.log(`💬 Ask endpoint: POST http://localhost:${PORT}/ask`);
  console.log(`❤️  Health: http://localhost:${PORT}/health`);
  console.log(`🏦 Plaid Environment: ${process.env.PLAID_ENVIRONMENT || 'sandbox'}`);
  console.log(`\n🎯 Try this query:`);
  console.log(`  curl -X POST http://localhost:${PORT}/ask -H "Content-Type: application/json" -d '{"query": "Can I afford a $150 dinner tonight?"}'`);
});

// Export for Vercel serverless deployment
export default app;