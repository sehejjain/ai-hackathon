# Inkeep Integration Architecture - SpendConscience Project

This diagram illustrates the complete Inkeep integration architecture for the SpendConscience financial assistant application.

```mermaid
graph TB
    %% iOS Application Layer
    subgraph "iOS Application (SwiftUI)"
        A[AIFinancialAssistantView] --> B[SpendConscienceAPIService]
        B --> C[User Queries & Financial Questions]
    end

    %% Inkeep Configuration Layer
    subgraph "Inkeep Configuration"
        D[inkeep.config.ts<br/>Main Config] --> E[spending.graph.ts<br/>Agent Graph Definition]
        F[src/spendconscience/inkeep.config.ts<br/>CLI Config] --> G[Model Settings<br/>GPT-5, GPT-4.1-mini, GPT-4.1-nano]
    end

    %% Inkeep API Layer
    subgraph "Inkeep API Services"
        H[Management API<br/>Port 3002] --> I[Agent Management<br/>& Configuration]
        J[Run API<br/>Port 3003] --> K[Agent Execution<br/>& Orchestration]
    end

    %% Agent Graph Layer
    subgraph "Inkeep Agent Graph - Financial Intelligence"
        L[SpendConscience Assistant<br/>Main Coordinator] --> M[Affordability Agent<br/>Purchase Decisions]
        L --> N[Financial Coach<br/>Personalized Advice]
        
        M --> O[Budget Analyzer<br/>Spending Analysis]
        M --> P[Future Commitments<br/>Calendar Analysis]
        M --> Q[Alternative Finder<br/>Budget-Friendly Options]
        
        N --> M
        N --> Q
    end

    %% MCP Server Layer
    subgraph "MCP Servers (Model Context Protocol)"
        R[Plaid MCP Server<br/>stdio://plaid-mcp-server] --> S[Financial Data Tools]
        T[Google Maps MCP Server<br/>stdio://google-maps-mcp-server] --> U[Location & Places Tools]
        V[Budget Data MCP Server<br/>http://localhost:8002/mcp] --> W[Budget Storage Tools]
    end

    %% External APIs Layer
    subgraph "External APIs"
        X[Plaid API<br/>Financial Data] --> Y[Transactions<br/>Accounts<br/>Balances]
        Z[Google Places API<br/>Location Services] --> AA[Nearby Restaurants<br/>Price Filtering]
    end

    %% Data Flow Connections
    C --> H
    C --> J
    
    D --> H
    F --> J
    
    H --> L
    J --> L
    
    O --> R
    Q --> T
    M --> V
    
    R --> X
    T --> Z
    
    %% Agent Tool Connections
    S --> AB[get_transactions<br/>get_accounts<br/>get_spending_by_category<br/>get_account_balance]
    U --> AC[search_nearby<br/>get_place_details]
    W --> AD[Budget Limits<br/>Spending Targets]

    %% Response Flow
    L --> AE[Agent Response<br/>& Recommendations]
    AE --> J
    J --> B
    B --> A

    %% Styling
    classDef iosApp fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef inkeepConfig fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef inkeepAPI fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef agents fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef mcpServers fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    classDef externalAPIs fill:#f1f8e9,stroke:#33691e,stroke-width:2px
    classDef tools fill:#f9fbe7,stroke:#827717,stroke-width:2px

    class A,B,C iosApp
    class D,E,F,G inkeepConfig
    class H,I,J,K inkeepAPI
    class L,M,N,O,P,Q agents
    class R,S,T,U,V,W mcpServers
    class X,Y,Z,AA externalAPIs
    class AB,AC,AD,AE tools
```

## Architecture Components

### 1. iOS Application Layer
- **AIFinancialAssistantView**: SwiftUI interface for user interactions
- **SpendConscienceAPIService**: Handles communication with Inkeep APIs
- **User Queries**: Natural language financial questions and requests

### 2. Inkeep Configuration
- **Main Config** (`inkeep.config.ts`): Defines tenant, API URLs, and agent graph
- **CLI Config** (`src/spendconscience/inkeep.config.ts`): Model settings and project configuration
- **Model Settings**: GPT-5 for base, GPT-4.1-mini for structured output, GPT-4.1-nano for summarization

### 3. Inkeep API Services
- **Management API** (Port 3002): Handles agent configuration and management
- **Run API** (Port 3003): Executes agent workflows and orchestrates responses

### 4. Agent Graph - Financial Intelligence System
- **SpendConscience Assistant**: Main coordinator that routes queries to specialist agents
- **Affordability Agent**: Makes purchase decisions based on real financial data
- **Budget Analyzer**: Analyzes spending patterns against budgets using Plaid data
- **Future Commitments**: Analyzes calendar events for upcoming expenses
- **Alternative Finder**: Finds budget-friendly alternatives when spending limits are reached
- **Financial Coach**: Provides personalized, actionable financial advice

### 5. MCP Servers (Model Context Protocol)
- **Plaid MCP Server**: Provides financial data access through standardized tools
- **Google Maps MCP Server**: Enables location-based restaurant and place searches
- **Budget Data MCP Server**: Manages user budget limits and spending targets

### 6. External APIs
- **Plaid API**: Real financial data including transactions, accounts, and balances
- **Google Places API**: Location services for finding nearby restaurants with price filtering

## Data Flow

1. **User Input**: User asks financial questions through iOS app
2. **API Routing**: Queries sent to Inkeep Run API for agent execution
3. **Agent Orchestration**: SpendConscience Assistant routes to appropriate specialist agents
4. **Data Retrieval**: Agents use MCP tools to fetch real financial and location data
5. **Analysis**: Multi-agent analysis combining budget, spending, and future commitments
6. **Response Generation**: Coordinated response with actionable recommendations
7. **UI Display**: Structured response displayed in iOS app with agent workflow visualization

## Key Features

- **Real-time Financial Data**: Direct integration with Plaid for actual transaction data
- **Multi-agent Intelligence**: Specialized agents for different aspects of financial analysis
- **Location-aware Recommendations**: Google Maps integration for budget-friendly alternatives
- **Calendar Integration**: Future expense prediction based on calendar events
- **Structured Responses**: Clear agent workflow and data source attribution
- **Model Optimization**: Different GPT models optimized for specific tasks

## Agent Trigger Conditions

- **Alternative Finder**: Activates when dining budget >90% used AND large dining expenses planned
- **Budget Analyzer**: Flags categories at >90% of monthly budget as "TRIGGER_ALTERNATIVES"
- **Affordability Agent**: Makes AFFORD/DON'T AFFORD/CAUTION decisions with numerical reasoning
