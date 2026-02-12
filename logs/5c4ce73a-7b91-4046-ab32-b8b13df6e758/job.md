Add Slack integration to thepopebot event handler to enable conversational chat via Slack, mirroring the existing Telegram functionality.

TASKS:

1. Create `event_handler/tools/slack.js` - Slack utility module with functions:
   - `sendMessage(channel, text, blocks)` - Send text/block messages to Slack
   - `sendReply(channelId, threadTs, text)` - Send threaded replies
   - `verifySlackRequest(req)` - Verify incoming Slack webhook signatures using SLACK_SIGNING_SECRET
   - `formatUserMention(userId)` - Format Slack user mentions
   - Parse incoming Slack events and extract user ID, channel ID, text, thread timestamp

2. Add Slack webhook route to `event_handler/server.js`:
   - POST `/slack/webhook` endpoint
   - Verify request signature using `slack.verifySlackRequest()`
   - Handle Slack event types: `url_verification` (challenge), `message` (app_mention, direct message)
   - Only respond to messages that mention the bot or are DMs
   - Ignore bot's own messages and message_changed/message_deleted events

3. Integrate Claude into Slack webhook:
   - Import existing Claude chat system from `event_handler/claude/`
   - When a Slack message is received, call Claude with the same system prompt as Telegram (from CHATBOT.md)
   - Claude should have access to the same tools: `create_job`, `get_job_status`, `web_search`
   - Send Claude's response back to Slack via `slack.sendMessage()` or `slack.sendReply()` if threaded
   - Handle tool use (create_job, get_job_status, web_search) just like Telegram does
   - Keep conversation history per Slack user/channel (similar to Telegram conversation.js)

4. Update environment variables:
   - Add to `.env.example`: `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `SLACK_SIGNING_SECRET`
   - Document that SLACK_SIGNING_SECRET comes from Slack app's "Signing Secret" in App Credentials
   - Add conditional startup: only initialize Slack if SLACK_BOT_TOKEN is set

5. Update documentation:
   - Add section to README explaining Slack setup steps:
     - Create Slack app at api.slack.com
     - Enable Event Subscriptions and subscribe to `app_mention`, `message.im` events
     - Set Event Subscriptions URL to `http://31.220.53.18:3000/slack/webhook`
     - Copy bot token, app token, signing secret to .env
     - Invite bot to channels

6. Test the integration:
   - Verify the webhook route starts without errors
   - Log confirmation that Slack integration is enabled on startup

CONTEXT:
- Event handler is running on Hostinger VPS at 31.220.53.18:3000
- User has Slack workspace, bot token, and app token ready
- Integration should mirror Telegram functionality exactly (Claude chat + tool use)
- Use existing Claude integration from event_handler/claude/ as template
- Reference event_handler/tools/telegram.js for similar patterns