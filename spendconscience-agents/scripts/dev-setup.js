#!/usr/bin/env node

import { spawn } from 'child_process';
import { promisify } from 'util';
import { exec } from 'child_process';

const execAsync = promisify(exec);

async function devSetup() {
  console.log('🚀 Starting Inkeep Agents development environment...');
  console.log('');
  
  try {
    // Start development servers in background
    console.log('📡 Starting development servers...');
    const devProcess = spawn('pnpm', ['dev'], {
      stdio: ['pipe', 'pipe', 'pipe'],
      detached: false
    });
    
    // Give servers time to start
    console.log('⏳ Waiting for servers to start...');
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    console.log('');
    console.log('📦 Servers are ready! Setting up project in database...');
    
    // Run the setup script
    await execAsync('pnpm setup');
    
    console.log('');
    console.log('🎉 Development environment is ready!');
    console.log('');
    console.log('📋 Available URLs:');
    console.log(`   - Management UI: http://localhost:3002`);
    console.log(`   - Runtime API:   http://localhost:3003`);
    console.log('');
    console.log('✨ The servers will continue running. Press Ctrl+C to stop.');
    
    // Keep the script running so servers don't terminate
    process.on('SIGINT', () => {
      console.log('\n👋 Shutting down development servers...');
      devProcess.kill();
      process.exit(0);
    });
    
    // Wait for the dev process to finish or be killed
    devProcess.on('close', (code) => {
      console.log(`Development servers stopped with code ${code}`);
      process.exit(code);
    });
    
  } catch (error) {
    console.error('❌ Failed to start development environment:', error.message);
    process.exit(1);
  }
}

devSetup();
