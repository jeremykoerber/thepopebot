const crypto = require('crypto');

const MAX_LENGTH = 4000; // Slack's block text limit

/**
 * Verify Slack webhook signature
 * @param {string} body - Raw request body
 * @param {string} timestamp - X-Slack-Request-Timestamp header
 * @param {string} signature - X-Slack-Request-Signature header
 * @param {string} signingSecret - Slack signing secret
 * @returns {boolean} Whether signature is valid
 */
function verifySlackSignature(body, timestamp, signature, signingSecret) {
  if (!signingSecret) return false;
  
  // Check timestamp isn't too old (5 minutes)
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - parseInt(timestamp)) > 300) {
    return false;
  }

  const baseString = `v0:${timestamp}:${body}`;
  const hmac = crypto
    .createHmac('sha256', signingSecret)
    .update(baseString)
    .digest('hex');
  const computedSignature = `v0=${hmac}`;

  try {
    return crypto.timingSafeEqual(
      Buffer.from(signature, 'utf8'),
      Buffer.from(computedSignature, 'utf8')
    );
  } catch (err) {
    // If buffers are different lengths, comparison fails (this is expected for invalid signatures)
    return false;
  }
}

/**
 * Send a message to a Slack channel
 * @param {string} token - Slack bot token
 * @param {string} channelId - Channel ID to send to
 * @param {string|Object} message - Message text or block object
 * @returns {Promise<Object>} - Slack API response
 */
async function sendMessage(token, channelId, message) {
  const body = typeof message === 'string' ? { text: message } : message;

  const response = await fetch('https://slack.com/api/chat.postMessage', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      channel: channelId,
      ...body,
    }),
  });

  const result = await response.json();
  if (!result.ok) {
    throw new Error(`Slack API error: ${result.error}`);
  }
  return result;
}

/**
 * Update a message in Slack
 * @param {string} token - Slack bot token
 * @param {string} channelId - Channel ID
 * @param {string} timestamp - Message timestamp
 * @param {string|Object} message - Updated message text or block object
 * @returns {Promise<Object>} - Slack API response
 */
async function updateMessage(token, channelId, timestamp, message) {
  const body = typeof message === 'string' ? { text: message } : message;

  const response = await fetch('https://slack.com/api/chat.update', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      channel: channelId,
      ts: timestamp,
      ...body,
    }),
  });

  const result = await response.json();
  if (!result.ok) {
    throw new Error(`Slack API error: ${result.error}`);
  }
  return result;
}

/**
 * Send a reply in a thread
 * @param {string} token - Slack bot token
 * @param {string} channelId - Channel ID
 * @param {string} threadTs - Thread timestamp
 * @param {string|Object} message - Message text or block object
 * @returns {Promise<Object>} - Slack API response
 */
async function sendThreadMessage(token, channelId, threadTs, message) {
  const body = typeof message === 'string' ? { text: message } : message;

  const response = await fetch('https://slack.com/api/chat.postMessage', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      channel: channelId,
      thread_ts: threadTs,
      ...body,
    }),
  });

  const result = await response.json();
  if (!result.ok) {
    throw new Error(`Slack API error: ${result.error}`);
  }
  return result;
}

/**
 * Add emoji reaction to a message
 * @param {string} token - Slack bot token
 * @param {string} channelId - Channel ID
 * @param {string} timestamp - Message timestamp
 * @param {string} emoji - Emoji name (without colons)
 * @returns {Promise<void>}
 */
async function addReaction(token, channelId, timestamp, emoji = 'thumbsup') {
  const response = await fetch('https://slack.com/api/reactions.add', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      channel: channelId,
      timestamp,
      name: emoji,
    }),
  });

  const result = await response.json();
  if (!result.ok && result.error !== 'already_reacted') {
    throw new Error(`Slack API error: ${result.error}`);
  }
}

/**
 * Get information about a user
 * @param {string} token - Slack bot token
 * @param {string} userId - User ID
 * @returns {Promise<Object>} - User info
 */
async function getUserInfo(token, userId) {
  const response = await fetch(`https://slack.com/api/users.info?user=${userId}`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`,
    },
  });

  const result = await response.json();
  if (!result.ok) {
    throw new Error(`Slack API error: ${result.error}`);
  }
  return result.user;
}

/**
 * Format a job notification message for Slack
 * @param {Object} params - Notification parameters
 * @param {string} params.jobId - Full job ID
 * @param {boolean} params.success - Whether job succeeded
 * @param {string} params.summary - Job summary text
 * @param {string} params.prUrl - PR URL
 * @returns {Object} - Slack block object
 */
function formatJobNotification({ jobId, success, summary, prUrl }) {
  const emoji = success ? '✅' : '⚠️';
  const color = success ? '#36a64f' : '#ff9900';
  const shortId = jobId.slice(0, 8);

  return {
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: `${emoji} Job ${shortId} ${success ? 'Complete' : 'Had Issues'}`,
        },
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: summary,
        },
      },
      {
        type: 'actions',
        elements: [
          {
            type: 'button',
            text: {
              type: 'plain_text',
              text: 'View PR',
            },
            url: prUrl,
            style: success ? 'primary' : 'danger',
          },
        ],
      },
    ],
  };
}

/**
 * Smart split text into chunks for Slack's text limit
 * @param {string} text - Text to split
 * @param {number} maxLength - Maximum chunk length
 * @returns {string[]} Array of chunks
 */
function smartSplit(text, maxLength = MAX_LENGTH) {
  if (text.length <= maxLength) return [text];

  const chunks = [];
  let remaining = text;

  while (remaining.length > 0) {
    if (remaining.length <= maxLength) {
      chunks.push(remaining);
      break;
    }

    const chunk = remaining.slice(0, maxLength);
    let splitAt = -1;

    // Try to split at natural boundaries
    for (const delim of ['\n\n', '\n', '. ', ' ']) {
      const idx = chunk.lastIndexOf(delim);
      if (idx > maxLength * 0.3) {
        splitAt = idx + delim.length;
        break;
      }
    }

    if (splitAt === -1) splitAt = maxLength;

    chunks.push(remaining.slice(0, splitAt).trimEnd());
    remaining = remaining.slice(splitAt).trimStart();
  }

  return chunks;
}

/**
 * Start a typing indicator (visually shown as "is typing")
 * Note: Slack doesn't have a true typing indicator for bots,
 * so we just resolve immediately. This is a no-op for compatibility.
 * @returns {Function} No-op stop function
 */
function startTypingIndicator() {
  return () => {};
}

module.exports = {
  verifySlackSignature,
  sendMessage,
  updateMessage,
  sendThreadMessage,
  addReaction,
  getUserInfo,
  formatJobNotification,
  smartSplit,
  startTypingIndicator,
};
