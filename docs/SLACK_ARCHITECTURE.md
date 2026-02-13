# Slack Integration Architecture

This document provides visual diagrams and detailed explanation of how Slack integrates into thepopebot's architecture.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     thepopebot Architecture                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                   Event Handler Layer                    │ │
│  │                 (Node.js Express Server)                 │ │
│  │                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │ │
│  │  │   Telegram   │  │    Slack     │  │    GitHub    │  │ │
│  │  │   Webhook    │  │   Webhook    │  │   Webhook    │  │ │
│  │  │              │  │              │  │              │  │ │
│  │  │  /telegram/  │  │   /slack/    │  │  /github/    │  │ │
│  │  │   webhook    │  │   webhook    │  │   webhook    │  │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │ │
│  │         │                  │                  │          │ │
│  │         ▼                  ▼                  ▼          │ │
│  │  ┌──────────────────────────────────────────────────┐   │ │
│  │  │            Claude AI Integration                │   │ │
│  │  │  (Conversation History + Tool Use)              │   │ │
│  │  └──────────────────────────────────────────────────┘   │ │
│  │         ▲                              ▲                │ │
│  │         │                              │                │ │
│  │  ┌──────┴──────┐                ┌─────┴────────┐       │ │
│  │  │  Job Status │                │ Job Summary  │       │ │
│  │  │   Tracker   │                │  Formatter   │       │ │
│  │  └─────────────┘                └──────────────┘       │ │
│  │                                                          │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                  Docker Agent Layer                      │ │
│  │  (Executes jobs via Pi coding agent)                     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
└─────────────────────────────────────────────────────────────────┘
```

## Request Flow: Slack Mention

```
Slack User                    Slack API                    Event Handler
    │                              │                              │
    │─ Types: @thepopebot hello ──▶│                              │
    │                              │                              │
    │                              │─ POST /slack/webhook ──────▶│
    │                              │      (with signature)        │
    │                              │                              │
    │                              │   ┌─ Verify signature       │
    │                              │   │─ Extract message        │
    │                              │   │─ Send to Claude         │
    │                              │   │─ Update history         │
    │                              │   └─ Format response        │
    │                              │                              │
    │                              │◀─ chat.postMessage ────────│
    │                              │   (thread response)          │
    │◀─ Message in thread ────────│                              │
    │   (with answer)              │                              │
```

## Event Flow Details

### 1. Webhook Reception & Verification

```
Incoming Slack Event
    ↓
Extract headers:
  • X-Slack-Request-Timestamp
  • X-Slack-Request-Signature
    ↓
Check timestamp (must be within 5 min)
    ↓
Verify HMAC-SHA256 signature
    ↓
Compare with SLACK_SIGNING_SECRET
    ↓
✓ Valid? → Process event
✗ Invalid? → Reject (401)
```

### 2. Event Type Routing

```
Webhook receives event.type:
    ├─ "url_verification"
    │   └─ Return challenge token (used for setup)
    │
    ├─ "event_callback"
    │   └─ Route event.event.type:
    │       ├─ "app_mention"
    │       │   └─ Process bot mention (main handler)
    │       │
    │       └─ "message"
    │           └─ Ignored (handled via mention)
    │
    └─ Other types
        └─ Acknowledged but ignored
```

### 3. Message Processing

```
User mentions: @thepopebot What's the status?
    ↓
Extract text (remove @mention):
    "What's the status?"
    ↓
Check channel authorization:
    ✓ Mention in SLACK_CHANNEL_ID? → Continue
    ✗ Different channel? → Ignore (unless thread)
    ↓
Emoji reaction (acknowledgment):
    await addReaction(..., 'thumbsup')
    ↓
Get conversation history:
    const history = getHistory(channelId)
    ↓
Call Claude AI:
    const { response, history: newHistory } = 
      await chat(messageText, history, tools, executors)
    ↓
Update conversation history:
    updateHistory(channelId, newHistory)
    ↓
Split response if needed:
    const chunks = smartSplit(response, 4000)
    ↓
Send as thread replies:
    for (const chunk of chunks) {
      await sendThreadMessage(..., threadTs, chunk)
    }
```

## Job Completion Flow

```
GitHub PR Created
    ↓
(auto-merge.yml merges PR)
    ↓
update-event-handler.yml triggers
    ↓
POST /github/webhook
    ├─ Extract job results
    ├─ Generate summary via Claude
    ├─ Extract success/failure
    │
    ├─ If TELEGRAM configured:
    │   └─ sendMessage(TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, summary)
    │       + Add to conversation history
    │
    └─ If SLACK configured:
        └─ formatJobNotification({ jobId, success, summary, prUrl })
            └─ sendMessage(SLACK_BOT_TOKEN, SLACK_CHANNEL_ID, formatted)
                + Add to conversation history
```

## Slack vs Telegram Data Flow

```
┌─────────────────────────────────────────────────────┐
│           Conversation System (Shared)              │
│                                                     │
│  • operating_system/CHATBOT.md (system prompt)     │
│  • claude/tools.js (tool definitions)              │
│  • claude/conversation.js (history management)     │
│                                                     │
└──────────────┬──────────────────────────┬──────────┘
               │                          │
        ┌──────▼──────┐            ┌──────▼──────┐
        │   Telegram   │            │    Slack     │
        │              │            │              │
        │ • Bot token  │            │ • Bot token  │
        │ • Chat ID    │            │ • Channel ID │
        │ • History    │            │ • History    │
        │   per chat   │            │   per channel│
        │              │            │              │
        │ Tools:       │            │ Tools:       │
        │ • sendMsg    │            │ • sendMsg    │
        │ • getFile    │            │ • sendThread │
        │ • react      │            │ • addReaction│
        │ • typeIndicator           │ • typeIndicator (noop)
        └──────────────┘            └──────────────┘
```

## Directory Structure: Slack Integration

```
/job/
├── event_handler/
│   ├── server.js
│   │   ├── imports slack.js
│   │   ├── POST /slack/webhook endpoint
│   │   ├── verifySlackSignature()
│   │   ├── app_mention handling
│   │   └── Job notification (Slack)
│   │
│   └── tools/
│       ├── slack.js (NEW)
│       │   ├── verifySlackSignature
│       │   ├── sendMessage
│       │   ├── sendThreadMessage
│       │   ├── updateMessage
│       │   ├── addReaction
│       │   ├── getUserInfo
│       │   ├── formatJobNotification
│       │   └── smartSplit
│       │
│       └── telegram.js (existing)
│
├── docs/
│   ├── SLACK_INTEGRATION.md
│   ├── SLACK_SETUP_QUICK.md
│   └── SLACK_ARCHITECTURE.md (this file)
│
├── test-slack-integration.js (NEW)
├── verify-slack-integration.sh (NEW)
└── SLACK_INTEGRATION_SUMMARY.md (NEW)
```

## Environment Configuration

### Runtime Variables

```
Event Handler Environment:

Core Auth:
  API_KEY                    - For /webhook endpoint
  GH_TOKEN                  - GitHub operations
  ANTHROPIC_API_KEY         - Claude AI

GitHub Config:
  GH_OWNER                  - Repository owner
  GH_REPO                   - Repository name

Telegram (optional):
  TELEGRAM_BOT_TOKEN        - Telegram bot
  TELEGRAM_WEBHOOK_SECRET   - Telegram verification
  TELEGRAM_CHAT_ID          - Telegram chat

Slack (optional):
  SLACK_BOT_TOKEN           - Slack bot (xoxb-...)
  SLACK_SIGNING_SECRET      - Slack signature verification
  SLACK_CHANNEL_ID          - Slack channel

GitHub Webhooks:
  GH_WEBHOOK_SECRET         - GitHub verification
```

### GitHub Actions Variables (GHCR)

```
Repository Settings → Secrets and variables → Actions:

Secrets (sensitive):
  - SLACK_BOT_TOKEN
  - SLACK_SIGNING_SECRET

Variables (non-sensitive):
  - SLACK_CHANNEL_ID
```

## Security Architecture

```
Incoming Webhook Request
    ↓
┌─────────────────────────────────────┐
│  Signature Verification             │
│  • Extract: X-Slack-Request-Timestamp
│  • Extract: X-Slack-Request-Signature
│  • Check: Timestamp within 5 min
│  • Compute: HMAC-SHA256 signature
│  • Compare: Signatures (timing-safe)
└─────────────────────────────────────┘
    ↓
✗ Invalid → Return 401
✓ Valid → Continue
    ↓
┌─────────────────────────────────────┐
│  Channel Authorization              │
│  • Extract: event.event.channel
│  • Check: channelId == SLACK_CHANNEL_ID
│  • OR: Is reply in thread (allowed)
└─────────────────────────────────────┘
    ↓
✗ Not authorized → Return 200 (silent)
✓ Authorized → Process message
```

## Concurrency & Error Handling

```
Webhook received
    ↓
Return 200 immediately (non-blocking)
    ↓
Process asynchronously:
    ├─ Add reaction (fire-and-forget)
    ├─ Call Claude API
    │   ├─ Success? → Send response
    │   └─ Error? → Send error message
    ├─ Update history
    └─ Send thread messages
        (auto-splits long responses)

All errors caught and logged
No webhook requests blocked by processing
User always gets 200 response
```

## Message Limits & Splitting

```
Slack text limit: 4000 characters per message

Smart split algorithm:
1. If text ≤ 4000 chars → Send as-is
2. Otherwise, find split point:
   a. Try split at \n\n (paragraph break)
   b. Try split at \n (line break)
   c. Try split at . (sentence break)
   d. Try split at space (word break)
   e. Fallback to character boundary
3. Keep 30% margin from limit
4. Repeat until all chunks sent
5. Maintain context across chunks

Example:
Input: 15000 char response
Output: 4 separate thread messages
```

## Conversation History Management

```
Per-channel memory:

{
  "C1234567890": [
    { role: "user", content: "What's the status?" },
    { role: "assistant", content: "Status: ..." },
    { role: "user", content: "How many jobs?" },
    { role: "assistant", content: "Jobs: ..." }
  ]
}

• Loaded on first mention in channel
• Updated after each Claude response
• Maintained in memory (not persisted)
• Separate from Telegram histories
• Lost on server restart
```

## Data Flow: Complete Picture

```
┌──────────────────────────────────────────────────────┐
│  User in Slack                                      │
└──────────────┬───────────────────────────────────────┘
               │
               │ @thepopebot What's new?
               ▼
        ┌────────────────┐
        │  Slack API     │
        └────────┬───────┘
                 │
        ┌────────▼───────────────┐
        │ POST /slack/webhook    │
        │ (event_handler/server) │
        └────────┬───────────────┘
                 │
        ┌────────▼──────────────────┐
        │ Signature Verification    │
        │ (event_handler/tools)     │
        └────────┬──────────────────┘
                 │
        ┌────────▼──────────────────┐
        │ Extract Message & Channel │
        │ Get Conversation History  │
        └────────┬──────────────────┘
                 │
        ┌────────▼──────────────────┐
        │ Call Claude API           │
        │ (event_handler/claude)    │
        └────────┬──────────────────┘
                 │
        ┌────────▼──────────────────┐
        │ Update History            │
        │ Split Response (if needed)│
        └────────┬──────────────────┘
                 │
        ┌────────▼───────────────────────┐
        │ Send Thread Messages (via API)  │
        │ (event_handler/tools/slack.js) │
        └────────┬───────────────────────┘
                 │
        ┌────────▼───────────────────┐
        │ Slack API (sendMessage)    │
        └────────┬───────────────────┘
                 │
                 ▼
        ┌──────────────────────┐
        │ Thread reply appears │
        │ in user's Slack      │
        └──────────────────────┘
```

## Integration Points

### 1. With Claude Chat System
- Uses same system prompt: `operating_system/CHATBOT.md`
- Uses same tools: `claude/tools.js`
- Uses same conversation management: `claude/conversation.js`
- Separate channel history from Telegram history

### 2. With Job System
- Listens to: GitHub webhook (`/github/webhook`)
- Accesses: Job results from PR payload
- Uses: Claude summarization (`summarizeJob()`)
- Outputs: Formatted notifications to Slack channel

### 3. With Operating System
- Reads: System prompt from `operating_system/CHATBOT.md`
- Reads: Job summary format from `operating_system/JOB_SUMMARY.md`
- Can be customized without code changes

## Feature Comparison

```
                    Telegram        Slack           Both
────────────────────────────────────────────────────────
Message limit       4096 chars      4000 chars      ✓
Threading           No              Yes             ✓
Reactions           Yes             Yes             ✓
File support        Voice msgs      Full API        ✓
Auth method         Token only      Token + Secret  Different
Setup complexity    Low             Medium          -
Enterprise support  Low             High            -
Rate limits         Generous        1 msg/sec       ✓
Direct messages     Yes             No              -
Channels            No              Yes             -
```

## Summary

The Slack integration fits seamlessly into thepopebot's two-layer architecture:

1. **Event Handler Layer** - Receives Slack webhooks, verifies signatures, routes messages to Claude
2. **Chat Layer** - Shared Claude AI system used by both Telegram and Slack
3. **Job Layer** - Notifies both platforms when jobs complete
4. **Security Layer** - HMAC-SHA256 verification per Slack standards

The implementation is:
- **Modular** - Separate Slack tools, easy to maintain
- **Secure** - Signature verification on all webhooks
- **Scalable** - Per-channel conversation histories
- **Extensible** - Can add more channels/platforms
- **Non-intrusive** - Doesn't affect existing Telegram functionality

For detailed setup and usage, see the accompanying documentation files.
