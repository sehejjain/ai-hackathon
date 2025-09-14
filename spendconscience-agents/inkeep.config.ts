import { spendingGraph } from './src/spendconscience/spending.graph.js';

export default {
  tenantId: 'spendconscience',
  agentsManageApiUrl: 'http://localhost:3002',
  agentsRunApiUrl: 'http://localhost:3003',
  graphs: [spendingGraph],
};