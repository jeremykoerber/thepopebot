# Slack Bot Integration

This document explains how to set up and use the Slack bot integration with thepopebot.

## Overview

The Slack integration allows thepopebot to:
- Respond to mentions in Slack channels
- Have conversations with Claude AI via Slack
- Receive job completion notifications
- Maintain conversation history per channel

The integration mirrors the Telegram bot functionality and uses the same Claude-powered conversational system.

## Setup Guide

### Step 1: Create a Slack App

1. Go to [Slack API Dashboard](https://api.slack.com/apps)
2. Click **Create New App**
3. Choose **From scratch**
4. Enter an app name (e.g., "thepopebot")
5. Select your Slack workspace
6. Click **Create App**

### Step 2: Configure OAuth & Permissions

1. In the left sidebar, go to **OAuth & Permissions**
2. Scroll to **Scopes** and add these **Bot Token Scopes**:
   - `chat:write` - Send messages
   - `chat:write.public` - Send messages in public channels
   - `reactions:write` - Add emoji reactions
   - `users:read` - Read user information
   - `app_mentions:read` - Receive mentions
   - `channels:read` - Read channel information

3. Scroll to the top and click **Install to Workspace** (if not already done)
4. Authorize the app when prompted

### Step 3: Get Your Tokens

1. From **OAuth & Permissions**, copy your **Bot User OAuth Token** (starts with `xoxb-`)
   - This is your `SLACK_BOT_TOKEN`

2. Go to **Basic Information** in the left sidebar
3. Scroll to **App Credentials** and copy the **Signing Secret**
   - This is your `SLACK_SIGNING_SECRET`

### Step 4: Find Your Channel ID

1. In Slack, right-click on the channel where you want to post
2. Select **View channel details**
3. At the bottom, copy the **Channel ID** (e.g., `C1234567890`)
   - This is your `SLACK_CHANNEL_ID`

**Note:** You can also get the channel ID by looking at the URL when you visit the channel in the web interface (the ID is in the URL after `/archives/`).

### Step 5: Configure Event Subscriptions

1. In the Slack API Dashboard, go to **Event Subscriptions**
2. Toggle **Enable Events** to ON
3. For **Request URL**, enter:
   ```
   https://your-domain.com/slack/webhook
   ```
4. Replace `your-domain.com` with your event handler's domain
5. Wait for Slack to verify the URL (it should show a green checkmark)
6. Under **Subscribe to bot events**, click **Add Bot User Event**
7. Add these events:
   - `app_mention` - When the bot is mentioned
8. Scroll to the bottom and click **Save Events**

### Step 6: Configure Environment Variables

Add these environment variables to your event handler:

```bash
# Slack Bot Token from OAuth & Permissions
SLACK_BOT_TOKEN=xoxb-your-token-here

# Signing Secret from Basic Information
SLACK_SIGNING_SECRET=your-signing-secret-here

# Channel ID where to receive notifications
SLACK_CHANNEL_ID=C1234567890
```

If using GitHub Actions, add these as **Secrets** (for sensitive data):
- `SLACK_BOT_TOKEN`
- `SLACK_SIGNING_SECRET`

And as **Variables** (for non-sensitive data):
- `SLACK_CHANNEL_ID`

## Usage

### Mentioning the Bot

In any Slack channel, mention the bot to ask it a question:

```
@thepopebot What's the status of my jobs?
```

The bot will respond in a thread with the answer.

### Job Notifications

When a job completes, thepopebot automatically posts a notification in your configured Slack channel:

- ✅ **Success** - Shows as green with a success emoji
- ⚠️ **Issues** - Shows as orange/red with a warning emoji
- Includes a summary of what the job did
- Has a "View PR" button linking to the GitHub PR

### Conversation History

Each Slack channel has its own conversation history with Claude. This means:
- Claude remembers previous messages in that channel
- Different channels have separate conversation contexts
- History is maintained in memory (not persisted to disk)

### Threading

When you mention the bot, it responds in a thread to keep conversations organized.

## API Endpoints

### POST /slack/webhook

Receives Slack events (mentions, challenges). Requires valid Slack signature verification.

**Request:**
```json
{
  "type": "event_callback",
  "event": {
    "type": "app_mention",
    "user": "U1234567890",
    "text": "@thepopebot Hello!",
    "channel": "C1234567890",
    "ts": "1234567890.123456"
  }
}
```

**Response:**
```json
{ "ok": true }
```

### URL Verification

Slack sends a challenge request when you set up event subscriptions:

**Request:**
```json
{
  "type": "url_verification",
  "challenge": "abc123def456..."
}
```

**Response:**
```json
{ "challenge": "abc123def456..." }
```

## Troubleshooting

### Bot isn't responding to mentions

1. Check that `SLACK_BOT_TOKEN` and `SLACK_SIGNING_SECRET` are set
2. Verify the Event Subscriptions URL is correct and verified (green checkmark)
3. Make sure the bot has the `app_mentions:read` scope
4. Check the event handler logs for errors

### "Unauthorized" errors

1. Verify `SLACK_SIGNING_SECRET` is correct (copy/paste from Slack API dashboard)
2. Check that your server's clock is synchronized (signature verification fails if timestamp is too old)

### Bot mentions create no response but no errors

1. Verify `SLACK_CHANNEL_ID` matches the channel where you're testing
2. Check that `SLACK_BOT_TOKEN` has all required scopes (especially `chat:write`)
3. Make sure the bot has been invited to the channel (add with `/invite @thepopebot`)

### Messages not splitting correctly

The bot automatically splits long messages at paragraph boundaries (4000 char limit). If a message appears truncated:
1. Check the full message was sent (may be in multiple parts)
2. Review the event handler logs for any truncation warnings

## Security

### Signature Verification

The bot verifies all incoming Slack requests using HMAC-SHA256 signatures. This ensures:
- Only requests from Slack are processed
- Requests haven't been tampered with
- Timestamp is recent (within 5 minutes)

### Bot Token Security

Your `SLACK_BOT_TOKEN` is sensitive:
- Never commit it to version control
- Use GitHub Secrets for CI/CD
- Rotate tokens periodically in Slack API dashboard

### Rate Limiting

Slack has rate limits on API calls:
- Chat messages: 1 per second per channel
- Reactions: 1 per second per user
- The bot respects these automatically

## Comparison with Telegram

| Feature | Slack | Telegram |
|---------|-------|----------|
| **Setup** | Requires Slack App | Simple bot token |
| **Mention** | `@bot message` | Direct message |
| **Threading** | Automatic in threads | Single conversation |
| **Reactions** | Emoji reactions | Emoji reactions |
| **Files** | Supported via Slack API | Voice messages supported |
| **Signature** | HMAC-SHA256 | Secret token header |

## Advanced Configuration

### Multiple Channels

To monitor multiple Slack channels, you would need to:
1. Create separate environment variables for each channel
2. Modify the webhook handler to route based on channel ID
3. Maintain separate conversation histories

This feature can be added if needed.

### Custom Responses

To customize how the bot responds, edit:
- `operating_system/CHATBOT.md` - System prompt
- `operating_system/JOB_SUMMARY.md` - Job summary formatting

These are shared with both Telegram and Slack.

### Disabling Slack

To disable Slack support without removing the code:
1. Don't set `SLACK_BOT_TOKEN` environment variable
2. The Slack webhook will be accessible but won't process mentions
3. Job notifications will only go to Telegram

## API Reference

### Slack Tools Module (`event_handler/tools/slack.js`)

#### `verifySlackSignature(body, timestamp, signature, signingSecret)`
Validates incoming Slack webhook signatures.

#### `sendMessage(token, channelId, message)`
Sends a message to a channel.

#### `sendThreadMessage(token, channelId, threadTs, message)`
Sends a reply in a thread.

#### `updateMessage(token, channelId, timestamp, message)`
Updates an existing message.

#### `addReaction(token, channelId, timestamp, emoji)`
Adds an emoji reaction to a message.

#### `formatJobNotification(params)`
Formats a job completion notification with buttons and styling.

#### `smartSplit(text, maxLength)`
Splits text at natural boundaries to fit Slack's 4000 char limit.

## Examples

### Ask the bot a question

```
Channel: #general
@thepopebot What Python version should I use?

Bot responds in thread:
Based on current best practices, Python 3.11 or 3.12 is recommended for new projects...
```

### Job completion notification

```
Channel: #general (configured SLACK_CHANNEL_ID)

✅ Job abc12345 Complete

Task: Deploy new feature X
Changed files: 2
PR: https://github.com/yourorg/yourrepo/pull/123

[View PR button]
```

### Conversation history

```
Channel: #dev-questions

User: @thepopebot How do I set up environment variables?
Bot: Here's how to set up environment variables...

(Later, in same channel)
User: @thepopebot And what about secrets?
Bot: Building on what we discussed about environment variables...
[Bot has context from previous message in same channel]
```

## Support

For issues with:
- **Slack API** - Visit [Slack API docs](https://api.slack.com/docs)
- **thepopebot Slack integration** - Check logs and refer to Troubleshooting section
- **Chat functionality** - Check `operating_system/CHATBOT.md` configuration
