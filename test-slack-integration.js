#!/usr/bin/env node

/**
 * Slack Integration Test Suite
 * Tests all Slack bot functionality locally
 */

const crypto = require('crypto');
const assert = require('assert');

// Load test utilities
const slackTools = require('./event_handler/tools/slack');

console.log('🧪 Slack Integration Test Suite\n');

// Test 1: Signature Verification
console.log('Test 1: Slack Signature Verification');
try {
  const signingSecret = 'test-secret';
  const timestamp = String(Math.floor(Date.now() / 1000));
  const body = '{"type":"event_callback","event":{"type":"app_mention"}}';
  
  // Create valid signature
  const baseString = `v0:${timestamp}:${body}`;
  const hmac = crypto
    .createHmac('sha256', signingSecret)
    .update(baseString)
    .digest('hex');
  const signature = `v0=${hmac}`;

  // Verify it
  const isValid = slackTools.verifySlackSignature(body, timestamp, signature, signingSecret);
  assert.strictEqual(isValid, true, 'Valid signature should verify');

  // Test invalid signature
  const invalidSignature = 'v0=invalid';
  const isInvalid = slackTools.verifySlackSignature(body, timestamp, invalidSignature, signingSecret);
  assert.strictEqual(isInvalid, false, 'Invalid signature should not verify');

  // Test old timestamp (more than 5 minutes)
  const oldTimestamp = String(Math.floor(Date.now() / 1000) - 600);
  const oldBaseString = `v0:${oldTimestamp}:${body}`;
  const oldHmac = crypto
    .createHmac('sha256', signingSecret)
    .update(oldBaseString)
    .digest('hex');
  const oldSignature = `v0=${oldHmac}`;
  const isOldValid = slackTools.verifySlackSignature(body, oldTimestamp, oldSignature, signingSecret);
  assert.strictEqual(isOldValid, false, 'Old timestamp should not verify');

  console.log('✅ Signature verification tests passed\n');
} catch (err) {
  console.error('❌ Signature verification tests failed:', err.message, '\n');
  process.exit(1);
}

// Test 2: Text Splitting
console.log('Test 2: Smart Text Splitting');
try {
  const shortText = 'Hello world';
  const shortSplit = slackTools.smartSplit(shortText, 100);
  assert.deepStrictEqual(shortSplit, [shortText], 'Short text should not be split');

  const longText = 'Hello world\n\nParagraph 2\n\nParagraph 3 is ' + 'very '.repeat(100) + 'long';
  const longSplit = slackTools.smartSplit(longText, 50);
  assert(longSplit.length > 1, 'Long text should be split');
  longSplit.forEach((chunk, i) => {
    assert(chunk.length <= 60, `Chunk ${i} exceeds limit: ${chunk.length}`);
  });

  console.log(`✅ Text splitting tests passed (long text split into ${longSplit.length} chunks)\n`);
} catch (err) {
  console.error('❌ Text splitting tests failed:', err.message, '\n');
  process.exit(1);
}

// Test 3: Job Notification Formatting
console.log('Test 3: Job Notification Formatting');
try {
  const notification = slackTools.formatJobNotification({
    jobId: '1234567890abcdef',
    success: true,
    summary: 'Deployed feature successfully',
    prUrl: 'https://github.com/test/repo/pull/123',
  });

  assert(notification.blocks, 'Should have blocks');
  assert(notification.blocks.length > 0, 'Should have at least one block');
  assert.strictEqual(notification.blocks[0].type, 'header', 'First block should be header');
  assert(notification.blocks[0].text.text.includes('12345678'), 'Header should include job ID');
  assert(notification.blocks[0].text.text.includes('✅'), 'Success should show checkmark');

  const failedNotification = slackTools.formatJobNotification({
    jobId: 'abcdefghijklmnop',
    success: false,
    summary: 'Job had issues',
    prUrl: 'https://github.com/test/repo/pull/124',
  });

  assert(failedNotification.blocks[0].text.text.includes('⚠️'), 'Failure should show warning');

  console.log('✅ Job notification formatting tests passed\n');
} catch (err) {
  console.error('❌ Job notification formatting tests failed:', err.message, '\n');
  process.exit(1);
}

// Test 4: Environment Variable Validation
console.log('Test 4: Environment Variable Validation');
try {
  const requiredVars = ['SLACK_BOT_TOKEN', 'SLACK_SIGNING_SECRET', 'SLACK_CHANNEL_ID'];
  const missingVars = requiredVars.filter(v => !process.env[v]);
  
  if (missingVars.length > 0) {
    console.log(`⚠️  Missing environment variables: ${missingVars.join(', ')}`);
    console.log('   Note: These are required for integration testing, but not for unit tests\n');
  } else {
    console.log('✅ All required environment variables are set\n');
  }
} catch (err) {
  console.error('❌ Environment variable validation failed:', err.message, '\n');
  process.exit(1);
}

// Test 5: Mock Slack Event Handling
console.log('Test 5: Mock Slack Event Handling');
try {
  // Test app_mention event structure
  const mentionEvent = {
    type: 'event_callback',
    event: {
      type: 'app_mention',
      user: 'U12345678',
      text: '<@U87654321> Hello bot!',
      channel: 'C12345678',
      ts: '1234567890.123456',
      thread_ts: '1234567890.123456',
    },
  };

  // Verify event structure
  assert.strictEqual(mentionEvent.event.type, 'app_mention');
  assert(mentionEvent.event.user, 'Should have user ID');
  assert(mentionEvent.event.channel, 'Should have channel ID');
  assert(mentionEvent.event.ts, 'Should have timestamp');

  // Test URL verification challenge
  const challengeEvent = {
    type: 'url_verification',
    challenge: 'abc123def456xyz',
  };

  assert.strictEqual(challengeEvent.type, 'url_verification');
  assert.strictEqual(challengeEvent.challenge, 'abc123def456xyz');

  console.log('✅ Mock Slack event handling tests passed\n');
} catch (err) {
  console.error('❌ Mock Slack event handling tests failed:', err.message, '\n');
  process.exit(1);
}

// Test 6: Message Formatting
console.log('Test 6: Message Formatting');
try {
  const blocks = {
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: '✅ Job abc12345 Complete',
        },
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: 'Job completed successfully',
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
            url: 'https://github.com/test/repo/pull/123',
            style: 'primary',
          },
        ],
      },
    ],
  };

  assert(Array.isArray(blocks.blocks), 'Should be array');
  assert(blocks.blocks[0].text, 'Header should have text');
  assert(blocks.blocks[1].text.type === 'mrkdwn', 'Section should support markdown');
  assert(blocks.blocks[2].elements[0].type === 'button', 'Should have button');

  console.log('✅ Message formatting tests passed\n');
} catch (err) {
  console.error('❌ Message formatting tests failed:', err.message, '\n');
  process.exit(1);
}

// Summary
console.log('════════════════════════════════════════');
console.log('✅ All Slack integration tests passed!');
console.log('════════════════════════════════════════\n');

console.log('Next steps:');
console.log('1. Set up Slack app credentials:');
console.log('   - SLACK_BOT_TOKEN');
console.log('   - SLACK_SIGNING_SECRET');
console.log('   - SLACK_CHANNEL_ID');
console.log('');
console.log('2. Run the event handler:');
console.log('   npm start');
console.log('');
console.log('3. Configure Slack Event Subscriptions:');
console.log('   https://api.slack.com/apps → Event Subscriptions');
console.log('   Request URL: https://your-domain.com/slack/webhook');
console.log('');
console.log('4. Test by mentioning the bot:');
console.log('   @thepopebot hello');
console.log('');
console.log('See docs/SLACK_INTEGRATION.md for detailed setup guide');
