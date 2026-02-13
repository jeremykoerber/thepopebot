#!/bin/bash

# Slack Integration Verification Script
# Checks that all components are in place and working

set -e

echo "════════════════════════════════════════"
echo "🔍 Slack Integration Verification"
echo "════════════════════════════════════════"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_file() {
  local file=$1
  local description=$2
  if [ -f "$file" ]; then
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    echo -e "${RED}✗${NC} $description (missing: $file)"
    return 1
  fi
}

check_content() {
  local file=$1
  local pattern=$2
  local description=$3
  if grep -q "$pattern" "$file"; then
    echo -e "${GREEN}✓${NC} $description"
    return 0
  else
    echo -e "${RED}✗${NC} $description (pattern not found in $file)"
    return 1
  fi
}

# Counter for results
TESTS=0
PASSED=0

# Test 1: Files exist
echo "1️⃣  Checking files..."
echo ""

TESTS=$((TESTS+1))
if check_file "event_handler/tools/slack.js" "Slack tools module"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_file "docs/SLACK_INTEGRATION.md" "Slack documentation"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_file "docs/SLACK_SETUP_QUICK.md" "Quick setup guide"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_file "test-slack-integration.js" "Test suite"; then
  PASSED=$((PASSED+1))
fi

echo ""
echo "2️⃣  Checking server.js integration..."
echo ""

TESTS=$((TESTS+1))
if check_content "event_handler/server.js" "slack" "Slack imports present"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "event_handler/server.js" "/slack/webhook" "Slack webhook endpoint"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "event_handler/server.js" "verifySlackSignature" "Signature verification"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "event_handler/server.js" "app_mention" "App mention handling"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "event_handler/server.js" "sendThreadMessage" "Thread message support"; then
  PASSED=$((PASSED+1))
fi

echo ""
echo "3️⃣  Checking Slack tools module..."
echo ""

TESTS=$((TESTS+1))
if check_content "event_handler/tools/slack.js" "verifySlackSignature" "Signature verification function"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "event_handler/tools/slack.js" "sendMessage" "Send message function"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "event_handler/tools/slack.js" "sendThreadMessage" "Thread message function"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "event_handler/tools/slack.js" "addReaction" "Add reaction function"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "event_handler/tools/slack.js" "formatJobNotification" "Job notification formatter"; then
  PASSED=$((PASSED+1))
fi

echo ""
echo "4️⃣  Checking CLAUDE.md documentation..."
echo ""

TESTS=$((TESTS+1))
if check_content "CLAUDE.md" "slack.js" "Slack in directory structure"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "CLAUDE.md" "/slack/webhook" "Slack webhook in endpoints"; then
  PASSED=$((PASSED+1))
fi

TESTS=$((TESTS+1))
if check_content "CLAUDE.md" "SLACK_BOT_TOKEN" "Slack environment variables"; then
  PASSED=$((PASSED+1))
fi

echo ""
echo "5️⃣  Running unit tests..."
echo ""

TESTS=$((TESTS+1))
if node test-slack-integration.js > /tmp/slack-test.log 2>&1; then
  echo -e "${GREEN}✓${NC} All unit tests passed"
  PASSED=$((PASSED+1))
else
  echo -e "${RED}✗${NC} Unit tests failed"
  cat /tmp/slack-test.log | tail -20
fi

echo ""
echo "════════════════════════════════════════"
echo "📊 Results"
echo "════════════════════════════════════════"
echo ""
echo "Tests: $PASSED / $TESTS passed"

if [ $PASSED -eq $TESTS ]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Follow setup guide: docs/SLACK_SETUP_QUICK.md"
  echo "2. Set environment variables:"
  echo "   - SLACK_BOT_TOKEN"
  echo "   - SLACK_SIGNING_SECRET"
  echo "   - SLACK_CHANNEL_ID"
  echo "3. Start event handler: npm start"
  echo "4. Test: @thepopebot hello"
  echo ""
  exit 0
else
  echo -e "${RED}✗ Some checks failed${NC}"
  echo ""
  exit 1
fi
