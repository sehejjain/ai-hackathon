# Agent Communication Flow in SpendConscience

## 🏗️ Architecture Overview

Your 4-agent system uses **hierarchical delegation** where agents can delegate tasks to specialized agents based on the query complexity and type.

## 🔄 Communication Patterns

### 1. **Entry Point**: SpendConscience Assistant (Coordinator)
```
User Query → SpendConscience Assistant (decides which agents to involve)
```

### 2. **Delegation Hierarchy**
```
SpendConscience Assistant
├── Affordability Agent (purchase decisions)
│   ├── Budget Analyzer (spending analysis)
│   └── Future Commitments (upcoming expenses)
├── Financial Coach (advice & coaching)
│   └── Affordability Agent (can delegate further)
├── Budget Analyzer (direct budget queries)
└── Future Commitments (direct calendar queries)
```

## 📋 Agent Communication Matrix

| Agent | Can Delegate To | Communication Purpose |
|-------|----------------|----------------------|
| **SpendConscience Assistant** | • Affordability Agent<br>• Financial Coach<br>• Budget Analyzer<br>• Future Commitments | Routes queries to specialists |
| **Affordability Agent** | • Budget Analyzer<br>• Future Commitments | Gathers data for purchase decisions |
| **Financial Coach** | • Affordability Agent | Gets financial analysis for coaching |
| **Budget Analyzer** | None (leaf agent) | Analyzes spending vs budget |
| **Future Commitments** | None (leaf agent) | Analyzes upcoming expenses |

## 🔄 Communication Flow Examples

### Example 1: "Can I afford a $50 dinner?"
```
1. User → SpendConscience Assistant
2. Assistant → Affordability Agent ("make purchase decision")
3. Affordability Agent → Budget Analyzer ("analyze current spending")
4. Affordability Agent → Future Commitments ("check upcoming expenses")
5. Affordability Agent → Assistant ("decision: AFFORD/DON'T AFFORD")
6. Assistant → Financial Coach ("provide personalized advice")
7. Coach → User (final response with decision + advice)
```

### Example 2: "How is my budget this month?"
```
1. User → SpendConscience Assistant
2. Assistant → Budget Analyzer ("analyze spending patterns")
3. Budget Analyzer → Assistant (spending analysis)
4. Assistant → Financial Coach ("provide budget insights")
5. Coach → User (budget overview + recommendations)
```

## 🛠️ Technical Implementation

### Inkeep AgentGraph Features:
- **`canDelegateTo()`**: Defines which agents can delegate to others
- **`canUse()`**: Defines which MCP tools agents can access
- **Automatic routing**: Inkeep handles the actual message passing
- **Context preservation**: Agent responses are automatically shared

### MCP Tool Access:
```
Budget Analyzer ← plaidTool, budgetTool
Future Commitments ← calendarTool
Affordability Agent ← (via delegation to Budget + Future)
Financial Coach ← (via delegation to Affordability)
SpendConscience Assistant ← (via delegation to all)
```

## 🎯 Key Benefits

1. **Separation of Concerns**: Each agent has a specific expertise
2. **Flexible Routing**: Complex queries automatically involve multiple agents
3. **Reusable Components**: Agents can be combined for different scenarios
4. **Scalable**: Easy to add new specialist agents
5. **Context Aware**: All agents share the conversation context

## 🔍 Behind the Scenes

When you ask "Can I afford a $50 dinner?":

1. **Intelligent Routing**: Assistant recognizes this as an affordability question
2. **Data Gathering**: Affordability agent delegates to specialists to gather:
   - Current spending patterns (Budget Analyzer)
   - Upcoming committed expenses (Future Commitments)
3. **Decision Making**: Affordability agent synthesizes data and makes decision
4. **Personalization**: Coach agent takes the decision and creates personalized advice
5. **Response**: User gets a complete answer with decision + coaching

The agents don't just pass data - they each add their specialized intelligence to create a comprehensive, personalized financial decision!