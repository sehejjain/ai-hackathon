# SpendConscience: Autonomous iOS Budgeting Agent

## 🚀 Quick Start for Developers

**New to the project? Get set up in 2 minutes:**

1. **Get your Plaid API credentials** and add them to your shell:
   ```bash
   export PLAID_CLIENT="your_client_id"
   export PLAID_SANDBOX_API="your_sandbox_secret"
   ```

2. **Run the setup script:**
   ```bash
   ./setup-development.sh
   ```

3. **Build and test:**
   ```bash
   xcodebuild test -project SpendConscience.xcodeproj -scheme SpendConscience -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'
   ```

**📋 For detailed setup instructions, see [TEAM_SETUP.md](TEAM_SETUP.md)**

---

## Project Overview

SpendConscience is a truly local-first iOS application that acts as an autonomous financial coach, helping users stay within their budgets through intelligent interventions and proactive spending guidance. Unlike traditional budgeting apps that simply track expenses after the fact, SpendConscience takes preventive action by analyzing spending patterns, calendar events, and financial goals to intervene before overspending occurs.

### Core Value Proposition

- **Autonomous Decision Making**: AI-powered agent that makes spending recommendations without constant user input
- **Proactive Interventions**: Prevents overspending before it happens, not just reporting after
- **True Privacy**: All data processing happens locally on device, zero cloud storage of financial data
- **Contextual Intelligence**: Understands calendar events, spending patterns, and personal preferences
- **Friction-Free Experience**: Minimal setup with maximum autonomy

## Architectural Philosophy

### Why We Rebuilt From Scratch

The original architecture suffered from fundamental contradictions:
- Claimed "local-first" while depending entirely on cloud relay servers
- Created unnecessary security vulnerabilities with server-side token storage
- Overengineered solutions for simple problems
- Misunderstood iOS capabilities and limitations
- Designed for complexity rather than functionality

### New Architecture Principles

1. **True Local-First**: All processing, storage, and intelligence happens on device
2. **Zero Custom Infrastructure**: No servers, no deployment, no maintenance overhead
3. **iOS-Native Integration**: Leverages platform capabilities instead of fighting them
4. **Privacy by Design**: User data never leaves their control
5. **MVP-Focused**: Prioritizes working functionality over theoretical completeness

## System Architecture

### High-Level Components

```
┌─────────────────────────────────────────────────────────────┐
│                    iOS APPLICATION                          │
├─────────────────────────────────────────────────────────────┤
│  Authentication Layer                                       │
│  • iCloud Keychain (credential storage & sync)             │
│  • Plaid Link SDK integration                              │
│  • Certificate pinning for API security                    │
├─────────────────────────────────────────────────────────────┤
│  Data Collection Layer                                      │
│  • Direct Plaid API integration (no proxy)                 │
│  • Transaction categorization & deduplication              │
│  • Local SQLite storage with encryption                    │
│  • Calendar event parsing via EventKit                     │
├─────────────────────────────────────────────────────────────┤
│  Intelligence Engine                                        │
│  • Spending pattern analysis                               │
│  • Budget forecasting & risk assessment                    │
│  • Context-aware intervention rules                        │
│  • Event cost estimation                                   │
├─────────────────────────────────────────────────────────────┤
│  AI Integration Layer                                       │
│  • Local LLM processing (llama.cpp/MLX)                   │
│  • Template-based fallback system                         │
│  • Personalized coaching message generation               │
│  • Tone adjustment (playful/serious)                      │
├─────────────────────────────────────────────────────────────┤
│  Action Execution Layer                                     │
│  • Local notification scheduling                           │
│  • Calendar event blocking via EventKit                    │
│  • iOS Reminders integration                              │
│  • Siri Shortcuts for voice commands                       │
├─────────────────────────────────────────────────────────────┤
│  User Interface Layer                                       │
│  • SwiftUI-based interface                                 │
│  • Manual refresh controls                                 │
│  • Budget configuration & preferences                      │
│  • Historical insights & reporting                         │
└─────────────────────────────────────────────────────────────┘

External Services (Read-Only):
┌─ Plaid API ─────────────────────────────────────────────────┐
│ • Direct HTTPS calls for transaction data                  │
│ • Account balance and metadata                             │
│ • No webhooks, no server-side integration                 │
└─────────────────────────────────────────────────────────────┘

┌─ iOS System Services ───────────────────────────────────────┐
│ • iCloud Keychain (credential synchronization)            │
│ • EventKit (calendar read/write access)                   │
│ • Reminders (task creation)                               │
│ • UserNotifications (local alerts)                        │
│ • SiriKit (voice command integration)                     │
└─────────────────────────────────────────────────────────────┘
```

### Data Architecture

**Local Storage Strategy:**
- **iCloud Keychain**: Plaid credentials, encrypted settings
- **SQLite Database**: Transaction history, budget data, action logs
- **UserDefaults**: App preferences, categorization rules
- **Local Files**: Export data, debug logs

**Security Boundaries:**
- All financial data remains on device
- Network calls only to Plaid API with certificate pinning
- Credentials encrypted and synced via iCloud Keychain
- No third-party analytics or tracking

## Tech Stack & Rationale

### Core Technologies

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **Platform** | Native iOS (Swift) | Required for iCloud Keychain, EventKit, proper iOS integration |
| **UI Framework** | SwiftUI | Fastest development for iOS-only app, modern declarative UI |
| **Database** | SQLite + SwiftData | Lightweight, embedded, perfect for financial data precision |
| **Networking** | URLSession | Native, secure, supports certificate pinning |
| **AI Processing** | Local LLM (llama.cpp/MLX) | Privacy-preserving, offline-capable, iOS-optimized |
| **Authentication** | iCloud Keychain | Secure credential storage with cross-device sync |
| **Banking Integration** | Plaid Link SDK | Industry standard, regulatory compliant |

### Alternative Frameworks Rejected

**React Native**: 
- Cannot access iCloud Keychain properly
- Bridge complexity for Plaid SDK integration
- Performance overhead for financial calculations
- Limited iOS system service access

**Flutter**:
- Requires custom platform channels for iOS features
- No direct iCloud Keychain support
- Additional complexity for calendar integration
- Larger app size due to embedded runtime

### AI Integration Strategy

**Local LLM Implementation:**
- 3B parameter model optimized for iOS (Qwen2-3B-Instruct)
- Quantized to 4-bit precision for memory efficiency
- Specialized prompts for financial coaching scenarios
- Fallback to template system if model unavailable

**Template Engine Backup:**
- Pre-written message templates for all scenarios
- Dynamic content insertion based on spending data
- Tone adjustment (playful vs. serious)
- Internationalization support

## Detailed System Flows

### Initial Setup Flow

1. **App Installation & Launch**
   - SwiftUI onboarding wizard
   - Permissions request (notifications, calendar, Siri)
   - Privacy explanation and consent

2. **Bank Account Connection**
   - Plaid Link SDK integration
   - User selects bank and authenticates
   - Access token received and stored in iCloud Keychain
   - Initial transaction sync (last 30 days)

3. **Budget Configuration**
   - Category-based budget setup
   - Spending preference learning
   - Intervention style selection (playful/serious)
   - Notification frequency preferences

4. **System Initialization**
   - Historical spending analysis
   - Pattern recognition setup
   - Calendar integration testing
   - Siri shortcut creation

### Daily Operation Flow

```
App Foreground → Manual Refresh → Plaid API Call → Transaction Processing
                                                           ↓
Calendar Check → Event Cost Estimation → Budget Impact Analysis
                                                           ↓
Risk Assessment → Intervention Decision → LLM Message Generation
                                                           ↓
User Notification → Action Approval → Calendar/Reminder Integration
```

### Real-Time Decision Making

**Spending Risk Analysis Pipeline:**
1. **Data Aggregation**: Current month transactions + calendar events
2. **Pattern Recognition**: Historical spending habits by category/day
3. **Forecasting**: Projected month-end spending based on current trajectory
4. **Risk Scoring**: Probability of budget overrun by category
5. **Intervention Planning**: Specific alternative suggestions
6. **Message Generation**: Personalized coaching content
7. **Action Execution**: Calendar blocks, reminders, notifications

### Background Processing (iOS Limitations Considered)

**Realistic Background Capabilities:**
- Local notifications scheduled based on spending triggers
- Background app refresh (when iOS allows it)
- Silent push equivalents using local scheduling
- Calendar event monitoring for cost estimation

**Working With iOS Constraints:**
- No persistent background processing
- Limited network access in background
- Notification scheduling instead of real-time processing
- User-initiated refresh as primary data sync method

## Use Cases & User Journeys

### Primary Use Cases

**1. Proactive Budget Warning**
- **Trigger**: User approaches 80% of category budget mid-month
- **Action**: Gentle notification with spending summary and alternatives
- **User Options**: Acknowledge, adjust budget, or set stricter limits

**2. Event-Based Spending Intervention**
- **Trigger**: Expensive calendar event detected (dinner reservation, concert)
- **Action**: Cost estimation and budget impact analysis
- **User Options**: Proceed, suggest alternatives, or reschedule

**3. Monthly Budget Review**
- **Trigger**: Month-end approaching with budget overrun risk
- **Action**: Comprehensive spending summary with next month suggestions
- **User Options**: Adjust categories, set goals, or modify behavior

**4. Voice-Activated Status Check**
- **Trigger**: "Hey Siri, how's my budget?"
- **Action**: Real-time spending status across all categories
- **Response**: Personalized summary with key insights

### User Journey Examples

**New User Onboarding (5 minutes):**
1. Download app → Privacy explanation
2. Connect bank account → Plaid Link authentication  
3. Set initial budgets → AI suggests based on spending history
4. Choose coaching style → Tone and intervention preferences
5. Grant permissions → Calendar, notifications, Siri access

**Daily Usage (< 30 seconds):**
1. Morning notification → "Good morning! You're on track this month"
2. Pre-purchase check → "Siri, can I afford this dinner?"
3. Real-time warning → "Hold up, you're at 85% of your dining budget"
4. End-of-day summary → Local notification with spending highlights

**Crisis Intervention:**
1. Budget overrun detected → Immediate notification
2. Alternative suggestions → Specific, actionable recommendations
3. Calendar blocking → Automatic event rescheduling suggestions
4. Habit adjustment → Long-term behavior modification tips

## Implementation Strategy

### 24-Hour Sprint Approach

**Phase 1: Core Foundation (Hours 1-6)**
- SwiftUI app structure and navigation
- Basic transaction model and SQLite schema
- Hardcoded demo data for reliable presentation
- Simple categorization logic

**Phase 2: Business Logic (Hours 7-12)**
- Budget tracking and risk assessment
- Local notification system implementation
- Template-based message generation
- Basic calendar integration mockups

**Phase 3: Demo Polish (Hours 13-18)**
- UI/UX refinement for presentation
- Demo script and data preparation
- Error handling and edge case management
- Simulator-optimized performance

**Phase 4: Integration & Testing (Hours 19-24)**
- End-to-end flow testing
- Demo scenario validation
- Presentation preparation
- Buffer time for critical bug fixes

### Development Team Structure

**Developer 1: iOS Platform Specialist**
- SwiftUI interface development
- iOS system integration (EventKit, Notifications, Siri)
- Local storage and data management
- Platform-specific optimizations

**Developer 2: Business Logic Specialist**
- Financial algorithms and forecasting
- AI integration and prompt engineering
- Business rule implementation
- Demo data preparation and testing

### Technical Milestones

**MVP Requirements (24-hour target):**
- [ ] Transaction display with categorization
- [ ] Basic budget tracking and warnings
- [ ] Local notification system
- [ ] Manual refresh mechanism
- [ ] Demo-ready UI with consistent branding
- [ ] Simulator-based presentation capability

**Future Enhancements (post-demo):**
- [ ] Real Plaid API integration
- [ ] Local LLM implementation
- [ ] Advanced forecasting algorithms
- [ ] Calendar integration with actual event blocking
- [ ] Comprehensive user testing and refinement

## Security & Privacy Model

### Data Privacy Architecture

**Local-First Principles:**
- All financial data processing happens on device
- No user data transmitted to third-party servers
- iCloud Keychain handles credential synchronization
- User maintains complete control over their information

**Security Implementations:**
- Certificate pinning for all external API calls
- AES encryption for sensitive local storage
- Keychain Services for credential management
- Biometric authentication for app access

**Compliance Considerations:**
- GDPR compliance through local-only processing
- No data retention policies needed (user-controlled)
- Audit trail maintained in local SQLite
- Right to deletion implemented via local data clearing

### Threat Model & Mitigations

**Identified Risks:**
1. **Device compromise**: Mitigated by iOS security model and encryption
2. **Network interception**: Prevented by certificate pinning and HTTPS
3. **App reverse engineering**: Acceptable risk for local-only processing
4. **Credential theft**: Mitigated by iCloud Keychain security

## Demo Strategy & Presentation

### Demo Environment Setup

**Simulator Configuration:**
- iOS 17+ simulator with full screen recording
- Xcode presentation mode for clean interface
- Pre-loaded demo data for consistent experience
- Mock calendar events showing integration capabilities

**Demo Script Flow:**
1. **Cold Start**: Fresh app installation and setup
2. **Data Import**: Simulated transaction categorization
3. **Budget Analysis**: Real-time risk assessment demonstration
4. **Intervention**: Triggered notification and user response
5. **Voice Integration**: Siri status check demonstration
6. **Calendar Integration**: Event cost estimation showcase

### Success Metrics

**Technical Achievements:**
- Functional iOS app running in simulator
- Demonstrated local-first architecture
- Working notification and calendar integration
- Voice command functionality via Siri

**Business Value Demonstration:**
- Clear user value proposition
- Practical spending intervention scenarios
- Privacy-preserving financial coaching
- Scalable architecture for real-world deployment

---

## Conclusion

SpendConscience represents a fundamental shift from reactive to proactive personal finance management. By leveraging local AI processing, native iOS integration, and privacy-by-design architecture, we've created a system that truly works as an autonomous agent while maintaining complete user privacy and control.

The 24-hour development approach prioritizes working functionality over theoretical completeness, ensuring a compelling demo that showcases the core value proposition while laying the groundwork for future enhancement and production deployment.

This architecture eliminates the contradictions and complexities of traditional fintech approaches, delivering a solution that is both technically sound and practically implementable by a small development team within aggressive timeline constraints.