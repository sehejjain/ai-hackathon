#!/usr/bin/env node

/**
 * Plaid MCP Server
 * Provides access to Plaid financial data through the Model Context Protocol
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool
} from '@modelcontextprotocol/sdk/types.js';
import { 
  PlaidApi, 
  Configuration, 
  PlaidEnvironments,
  TransactionsGetRequest,
  AccountsGetRequest,
  TransactionsGetResponse,
  AccountsGetResponse,
  Transaction
} from 'plaid';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Plaid client configuration
const configuration = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENVIRONMENT as keyof typeof PlaidEnvironments] || PlaidEnvironments.sandbox,
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
});

const plaidClient = new PlaidApi(configuration);

// MCP Server setup
const server = new Server(
  {
    name: 'plaid-mcp-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tool definitions
const tools: Tool[] = [
  {
    name: 'get_transactions',
    description: 'Get user transactions from Plaid for spending analysis',
    inputSchema: {
      type: 'object',
      properties: {
        access_token: {
          type: 'string',
          description: 'Plaid access token for the user account'
        },
        start_date: {
          type: 'string',
          format: 'date',
          description: 'Start date for transactions (YYYY-MM-DD)'
        },
        end_date: {
          type: 'string',
          format: 'date',
          description: 'End date for transactions (YYYY-MM-DD)'
        },
        account_ids: {
          type: 'array',
          items: { type: 'string' },
          description: 'Optional: specific account IDs to fetch transactions from'
        },
        count: {
          type: 'number',
          description: 'Maximum number of transactions to return (default: 100)',
          default: 100
        }
      },
      required: ['access_token', 'start_date', 'end_date']
    }
  },
  {
    name: 'get_accounts',
    description: 'Get user account information and balances from Plaid',
    inputSchema: {
      type: 'object',
      properties: {
        access_token: {
          type: 'string',
          description: 'Plaid access token for the user account'
        }
      },
      required: ['access_token']
    }
  },
  {
    name: 'get_spending_by_category',
    description: 'Analyze spending patterns by category for budget analysis',
    inputSchema: {
      type: 'object',
      properties: {
        access_token: {
          type: 'string',
          description: 'Plaid access token for the user account'
        },
        start_date: {
          type: 'string',
          format: 'date',
          description: 'Start date for analysis (YYYY-MM-DD)'
        },
        end_date: {
          type: 'string',
          format: 'date',
          description: 'End date for analysis (YYYY-MM-DD)'
        }
      },
      required: ['access_token', 'start_date', 'end_date']
    }
  },
  {
    name: 'get_account_balance',
    description: 'Get current account balances for affordability calculations',
    inputSchema: {
      type: 'object',
      properties: {
        access_token: {
          type: 'string',
          description: 'Plaid access token for the user account'
        },
        account_type: {
          type: 'string',
          enum: ['checking', 'savings', 'credit', 'all'],
          description: 'Type of accounts to include in balance calculation',
          default: 'all'
        }
      },
      required: ['access_token']
    }
  }
];

// Helper functions for transaction analysis
function categorizeSpending(transactions: Transaction[]): Record<string, number> {
  const categoryTotals: Record<string, number> = {};
  
  transactions.forEach(transaction => {
    const category = transaction.category?.[0] || 'Other';
    const amount = Math.abs(transaction.amount); // Plaid amounts are negative for spending
    
    if (!categoryTotals[category]) {
      categoryTotals[category] = 0;
    }
    categoryTotals[category] += amount;
  });
  
  return categoryTotals;
}

function calculateAvailableFunds(accounts: any[]): number {
  return accounts
    .filter(account => account.type === 'depository') // checking/savings
    .reduce((total, account) => {
      return total + (account.balances.available || account.balances.current || 0);
    }, 0);
}

// Tool handlers
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'get_transactions': {
        const { access_token, start_date, end_date, account_ids, count = 100 } = args as any;
        
        const request: TransactionsGetRequest = {
          access_token,
          start_date,
          end_date,
          ...(account_ids && { account_ids })
        };

        const response = await plaidClient.transactionsGet(request);
        
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                transactions: response.data.transactions.map((t: any) => ({
                  id: t.transaction_id,
                  account_id: t.account_id,
                  amount: t.amount,
                  date: t.date,
                  name: t.name,
                  merchant_name: t.merchant_name,
                  category: t.category,
                  subcategory: t.category?.[1],
                  location: t.location,
                  payment_channel: t.payment_channel
                })),
                total_transactions: response.data.total_transactions,
                accounts: response.data.accounts.map((a: any) => ({
                  id: a.account_id,
                  name: a.name,
                  type: a.type,
                  subtype: a.subtype
                }))
              }, null, 2)
            }
          ]
        };
      }

      case 'get_accounts': {
        const { access_token } = args as any;
        
        const request: AccountsGetRequest = {
          access_token
        };

        const response = await plaidClient.accountsGet(request);
        
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                accounts: response.data.accounts.map((account: any) => ({
                  id: account.account_id,
                  name: account.name,
                  type: account.type,
                  subtype: account.subtype,
                  balances: {
                    available: account.balances.available,
                    current: account.balances.current,
                    limit: account.balances.limit,
                    currency: account.balances.iso_currency_code
                  }
                }))
              }, null, 2)
            }
          ]
        };
      }

      case 'get_spending_by_category': {
        const { access_token, start_date, end_date } = args as any;
        
        const request: TransactionsGetRequest = {
          access_token,
          start_date,
          end_date
        };

        const response = await plaidClient.transactionsGet(request);
        const spendingTransactions = response.data.transactions.filter((t: any) => t.amount > 0); // Positive amounts are spending in Plaid
        const categoryTotals = categorizeSpending(spendingTransactions);
        
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                spending_by_category: categoryTotals,
                total_spending: Object.values(categoryTotals).reduce((sum, amount) => sum + amount, 0),
                transaction_count: spendingTransactions.length,
                date_range: { start_date, end_date },
                top_categories: Object.entries(categoryTotals)
                  .sort(([,a], [,b]) => b - a)
                  .slice(0, 5)
                  .map(([category, amount]) => ({ category, amount }))
              }, null, 2)
            }
          ]
        };
      }

      case 'get_account_balance': {
        const { access_token, account_type = 'all' } = args as any;
        
        const request: AccountsGetRequest = {
          access_token
        };

        const response = await plaidClient.accountsGet(request);
        
        let filteredAccounts = response.data.accounts;
        if (account_type !== 'all') {
          filteredAccounts = response.data.accounts.filter((account: any) => {
            switch (account_type) {
              case 'checking':
                return account.subtype === 'checking';
              case 'savings':
                return account.subtype === 'savings';
              case 'credit':
                return account.type === 'credit';
              default:
                return true;
            }
          });
        }

        const availableFunds = calculateAvailableFunds(filteredAccounts);
        
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                total_available_funds: availableFunds,
                account_type_filter: account_type,
                accounts: filteredAccounts.map((account: any) => ({
                  id: account.account_id,
                  name: account.name,
                  type: account.type,
                  subtype: account.subtype,
                  available_balance: account.balances.available,
                  current_balance: account.balances.current
                }))
              }, null, 2)
            }
          ]
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            error: `Plaid API Error: ${errorMessage}`,
            tool: name,
            timestamp: new Date().toISOString()
          }, null, 2)
        }
      ],
      isError: true
    };
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  
  console.error('🏦 Plaid MCP Server started successfully');
  console.error('📊 Available tools: get_transactions, get_accounts, get_spending_by_category, get_account_balance');
  console.error(`🌐 Environment: ${process.env.PLAID_ENVIRONMENT || 'sandbox'}`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error('Failed to start Plaid MCP server:', error);
    process.exit(1);
  });
}

export { server };