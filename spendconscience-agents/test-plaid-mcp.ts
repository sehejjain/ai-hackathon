#!/usr/bin/env node

/**
 * Test script for Plaid MCP Server
 * This runs the MCP server and tests its functionality
 */

import { spawn } from 'child_process';
import { readFileSync } from 'fs';
import path from 'path';

async function testPlaidMCP() {
  console.log('🏦 Starting Plaid MCP Server Test...\n');

  // Check environment configuration
  console.log('📋 Environment Check:');
  console.log(`   PLAID_CLIENT_ID: ${process.env.PLAID_CLIENT_ID ? '✅ Set' : '❌ Missing'}`);
  console.log(`   PLAID_SECRET: ${process.env.PLAID_SECRET ? '✅ Set' : '❌ Missing'}`);
  console.log(`   PLAID_ENVIRONMENT: ${process.env.PLAID_ENVIRONMENT || 'sandbox'}`);
  console.log('');

  // Start the MCP server
  console.log('🚀 Starting MCP Server...');
  const mcpServer = spawn('npx', ['tsx', 'mcp-servers/plaid-mcp-server.ts'], {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env }
  });

  let serverStarted = false;

  mcpServer.stderr.on('data', (data) => {
    const output = data.toString();
    console.log(`🔧 Server: ${output.trim()}`);
    
    if (output.includes('Plaid MCP Server started successfully')) {
      serverStarted = true;
      console.log('✅ MCP Server is running!\n');
      
      // Test the server with mock requests
      testMCPCommunication(mcpServer);
    }
  });

  mcpServer.stdout.on('data', (data) => {
    console.log(`📤 Server Response: ${data.toString().trim()}`);
  });

  mcpServer.on('close', (code) => {
    console.log(`\n🔴 MCP Server exited with code ${code}`);
  });

  mcpServer.on('error', (error) => {
    console.error(`❌ Error starting MCP server: ${error.message}`);
  });

  // Cleanup on exit
  process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down MCP server...');
    mcpServer.kill();
    process.exit(0);
  });
}

function testMCPCommunication(mcpServer: any) {
  console.log('🧪 Testing MCP Communication...\n');

  // Test 1: List available tools
  const listToolsRequest = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/list'
  };

  console.log('📋 Test 1: Listing available tools');
  mcpServer.stdin.write(JSON.stringify(listToolsRequest) + '\n');

  setTimeout(() => {
    // Test 2: Test get_accounts tool (will fail without real access token, but tests structure)
    const getAccountsRequest = {
      jsonrpc: '2.0',
      id: 2,
      method: 'tools/call',
      params: {
        name: 'get_accounts',
        arguments: {
          access_token: 'test-token-for-structure-validation'
        }
      }
    };

    console.log('\n💳 Test 2: Testing get_accounts tool structure (expected to fail gracefully)');
    mcpServer.stdin.write(JSON.stringify(getAccountsRequest) + '\n');
  }, 1000);

  setTimeout(() => {
    // Test 3: Test get_spending_by_category tool
    const getSpendingRequest = {
      jsonrpc: '2.0',
      id: 3,
      method: 'tools/call',
      params: {
        name: 'get_spending_by_category',
        arguments: {
          access_token: 'test-token-for-structure-validation',
          start_date: '2025-01-01',
          end_date: '2025-01-31'
        }
      }
    };

    console.log('\n📊 Test 3: Testing get_spending_by_category tool structure');
    mcpServer.stdin.write(JSON.stringify(getSpendingRequest) + '\n');
  }, 2000);

  setTimeout(() => {
    console.log('\n✅ MCP Server tests completed!');
    console.log('\n📝 Next Steps:');
    console.log('   1. Set up real Plaid credentials in .env file');
    console.log('   2. Get a valid Plaid access token for testing');
    console.log('   3. Connect this MCP server to your Inkeep agents');
    console.log('   4. Test the full financial decision workflow\n');
    
    console.log('🔗 To connect to agents, the MCP server should run on: stdio://');
    console.log('   The agents will communicate via stdin/stdout JSON-RPC\n');
  }, 3000);
}

// Load environment and start test
import dotenv from 'dotenv';
dotenv.config();

testPlaidMCP().catch(console.error);