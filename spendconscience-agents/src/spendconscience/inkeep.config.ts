import { defineConfig } from '@inkeep/agents-cli/config';

const config = defineConfig({
  tenantId: "default",
  projectId: "spendconscience",
  agentsManageApiUrl: `http://localhost:${process.env.MANAGE_API_PORT || '3002'}`,
  agentsRunApiUrl: `http://localhost:${process.env.RUN_API_PORT || '3003'}`,
  modelSettings: {
  "base": {
    "model": "openai/gpt-5-2025-08-07"
  },
  "structuredOutput": {
    "model": "openai/gpt-4.1-mini-2025-04-14"
  },
  "summarizer": {
    "model": "openai/gpt-4.1-nano-2025-04-14"
  }
},
});
    
export default config;