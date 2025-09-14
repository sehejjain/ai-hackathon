import { serve } from '@hono/node-server';
import { createExecutionApp } from '@inkeep/agents-run-api';
import { credentialStores } from '../../shared/credential-stores.js';
import { getLogger } from '@inkeep/agents-core';

const logger = getLogger('execution-api');

const port = process.env.RUN_API_PORT !== undefined
  ? Number(process.env.RUN_API_PORT)
  : 3003;

// Create the Hono app
const app = createExecutionApp({
  serverConfig: {
    port,
    serverOptions: {
      requestTimeout: 120000,
      keepAliveTimeout: 60000,
      keepAlive: true,
    },
  },
  credentialStores,
});

// Start the server using @hono/node-server
serve(
  {
    fetch: app.fetch,
    port,
  },
  (info) => {
    logger.info({}, `📝 Run API running on http://localhost:${info.port}`);
    logger.info({}, `📝 OpenAPI documentation available at http://localhost:${info.port}/openapi.json`);
  }
);