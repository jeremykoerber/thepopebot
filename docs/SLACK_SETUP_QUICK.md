# Slack Integration - Quick Setup

## TL;DR

1. **Create Slack App**: https://api.slack.com/apps → "Create New App" → "From scratch"

2. **Get Bot Token**:
   - OAuth & Permissions → Install to Workspace
   - Copy **Bot User OAuth Token** (xoxb-...)
   - Add scopes: `chat:write`, `chat:write.public`, `reactions:write`, `users:read`, `app_mentions:read`, `channels:read`

3. **Get Signing Secret**:
   - Basic Information → App Credentials
   - Copy **Signing Secret**

4. **Get Channel ID**:
   - Right-click channel in Slack → View details → Copy Channel ID

5. **Enable Event Subscriptions**:
   - Event Subscriptions → Enable Events
   - Request URL: `https://your-domain.com/slack/webhook`
   - Subscribe to `app_mention` event
   - Save

6. **Set Environment Variables**:
   ```bash
   SLACK_BOT_TOKEN=xoxb-your-token
   SLACK_SIGNING_SECRET=your-secret
   SLACK_CHANNEL_ID=C1234567890
   ```

7. **Test**:
   ```bash
   node test-slack-integration.js
   npm start
   # Then mention in Slack: @thepopebot hello
   ```

## Files

- `event_handler/tools/slack.js` - Slack API integration
- `event_handler/server.js` - Webhook handler (updated)
- `docs/SLACK_INTEGRATION.md` - Full documentation
- `test-slack-integration.js` - Test suite

## Environment Variables (GitHub Actions)

**Add as Secrets:**
- `SLACK_BOT_TOKEN` (from step 2)
- `SLACK_SIGNING_SECRET` (from step 3)

**Add as Variables:**
- `SLACK_CHANNEL_ID` (from step 4)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Bot not responding | Check `SLACK_SIGNING_SECRET` matches dashboard; verify Event Subscriptions URL |
| "Unauthorized" errors | Verify signing secret; check server clock is synchronized |
| Bot can't send messages | Add `chat:write` scope; invite bot to channel |
| Message formatting broken | Bot auto-splits at 4000 chars; check full message sent |

## Features

✅ Respond to mentions  
✅ Conversational AI (Claude)  
✅ Job completion notifications  
✅ Thread responses  
✅ Emoji reactions  
✅ Conversation history per channel  

## Next

See `docs/SLACK_INTEGRATION.md` for complete documentation.
