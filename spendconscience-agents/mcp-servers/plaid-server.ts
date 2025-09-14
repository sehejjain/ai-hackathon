import express from 'express';
import cors from 'cors';
import { Configuration, PlaidApi, PlaidEnvironments, TransactionsGetRequest } from 'plaid';

const app = express();
app.use(cors());
app.use(express.json());

// Plaid configuration
const configuration = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENVIRONMENT || 'sandbox'],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
});

const plaidClient = new PlaidApi(configuration);

// Mock user access tokens (in real app, these would be stored per user)
const MOCK_ACCESS_TOKENS: Record<string, string> = {
  'demo-user': 'access-sandbox-demo-token',
};

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'SpendConscience Plaid MCP Server' });
});

// MCP endpoint for Plaid transactions
app.post('/mcp', async (req, res) => {
  try {
    const { method, params } = req.body;
    
    if (method === 'tools/list') {
      return res.json({
        tools: [
          {
            name: 'get_transactions',
            description: 'Fetch user transactions from Plaid',
            inputSchema: {
              type: 'object',
              properties: {
                userId: { type: 'string', description: 'User ID' },
                startDate: { type: 'string', description: 'Start date (YYYY-MM-DD)' },
                endDate: { type: 'string', description: 'End date (YYYY-MM-DD)' },
                count: { type: 'number', description: 'Number of transactions', default: 100 }
              },
              required: ['userId']
            }
          },
          {
            name: 'get_accounts',
            description: 'Fetch user accounts from Plaid',
            inputSchema: {
              type: 'object',
              properties: {
                userId: { type: 'string', description: 'User ID' }
              },
              required: ['userId']
            }
          }
        ]
      });
    }
    
    if (method === 'tools/call') {
      const { name, arguments: args } = params;
      
      if (name === 'get_transactions') {
        const { userId, startDate, endDate, count = 100 } = args;
        const accessToken = MOCK_ACCESS_TOKENS[userId];
        
        if (!accessToken) {
          return res.status(400).json({
            error: 'User not found or no access token available'
          });
        }
        
        // For demo purposes, return mock data
        // In production, you would call Plaid API
        const mockTransactions = [
          {
            transaction_id: 'tx_1',
            account_id: 'acc_checking',
            amount: 25.50,
            date: '2024-01-15',
            name: 'Coffee Shop Purchase',
            merchant_name: 'Local Coffee Co',
            category: ['Food and Drink', 'Restaurants', 'Coffee Shop'],
            account_owner: null
          },
          {
            transaction_id: 'tx_2',
            account_id: 'acc_checking', 
            amount: 1200.00,
            date: '2024-01-01',
            name: 'Monthly Rent Payment',
            merchant_name: 'Property Management LLC',
            category: ['Payment', 'Rent'],
            account_owner: null
          },
          {
            transaction_id: 'tx_3',
            account_id: 'acc_checking',
            amount: 87.50,
            date: '2024-01-12',
            name: 'Grocery Store',
            merchant_name: 'Whole Foods Market',
            category: ['Shops', 'Food and Beverage Store', 'Supermarkets and Groceries'],
            account_owner: null
          }
        ];
        
        return res.json({
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                transactions: mockTransactions,
                total_transactions: mockTransactions.length,
                request_id: 'demo-request-id'
              })
            }
          ]
        });
      }
      
      if (name === 'get_accounts') {
        const { userId } = args;
        const accessToken = MOCK_ACCESS_TOKENS[userId];
        
        if (!accessToken) {
          return res.status(400).json({
            error: 'User not found or no access token available'
          });
        }
        
        const mockAccounts = [
          {
            account_id: 'acc_checking',
            balances: {
              available: 2500.50,
              current: 2500.50,
              limit: null,
              iso_currency_code: 'USD'
            },
            mask: '0000',
            name: 'Checking Account',
            official_name: 'Primary Checking Account',
            subtype: 'checking',
            type: 'depository'
          },
          {
            account_id: 'acc_savings',
            balances: {
              available: 10000.00,
              current: 10000.00,
              limit: null,
              iso_currency_code: 'USD'
            },
            mask: '1111',
            name: 'Savings Account',
            official_name: 'High Yield Savings',
            subtype: 'savings',
            type: 'depository'
          }
        ];
        
        return res.json({
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                accounts: mockAccounts,
                request_id: 'demo-request-id'
              })
            }
          ]
        });
      }
    }
    
    res.status(400).json({ error: 'Unknown method or tool' });
  } catch (error) {
    console.error('MCP Server Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 8001;
app.listen(PORT, () => {
  console.log(`🏦 SpendConscience Plaid MCP Server running on port ${PORT}`);
  console.log(`📝 Health check: http://localhost:${PORT}/health`);
  console.log(`🔧 MCP endpoint: http://localhost:${PORT}/mcp`);
});