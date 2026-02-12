#!/bin/bash
set -e
set -x  # Enable bash trace mode to log every command

echo "=========================================="
echo "Starting entrypoint.sh"
echo "=========================================="
echo "Current time: $(date)"
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo ""

# Extract job ID from branch name (job/uuid -> uuid), fallback to random UUID
echo ">>> Extracting Job ID from branch: BRANCH='${BRANCH}'"
if [[ "$BRANCH" == job/* ]]; then
    JOB_ID="${BRANCH#job/}"
    echo "Job ID extracted from branch: ${JOB_ID}"
else
    JOB_ID=$(cat /proc/sys/kernel/random/uuid)
    echo "Job ID generated randomly: ${JOB_ID}"
fi
echo "Final Job ID: ${JOB_ID}"
echo ""

# Start Chrome (using Puppeteer's chromium from pi-skills browser-tools)
echo ">>> Starting Chrome on port 9222..."
CHROME_BIN=$(find /root/.cache/puppeteer -name "chrome" -type f | head -1)
echo "Chrome binary found at: ${CHROME_BIN}"

if [ -z "$CHROME_BIN" ]; then
    echo "ERROR: Chrome binary not found!"
    exit 1
fi

# Start Chrome with error handling
$CHROME_BIN --headless --no-sandbox --disable-gpu --remote-debugging-port=9222 2>/dev/null &
CHROME_PID=$!
echo "Chrome started with PID: ${CHROME_PID}"

# Wait for Chrome to be ready
echo "Waiting for Chrome to become responsive..."
sleep 2

# Verify Chrome process is still running
if ! kill -0 $CHROME_PID 2>/dev/null; then
    echo "ERROR: Chrome process (PID ${CHROME_PID}) died unexpectedly!"
    exit 1
fi
echo "Chrome process still running (PID: ${CHROME_PID})"

# Check if Chrome is listening on port 9222
echo "Checking Chrome connectivity on localhost:9222..."
if timeout 5 curl -s http://localhost:9222 >/dev/null 2>&1; then
    echo "✓ Chrome is responsive on port 9222"
else
    echo "WARNING: Chrome not responding to curl, but will continue"
fi
echo ""

# Export SECRETS (base64 JSON) as flat env vars (GH_TOKEN, ANTHROPIC_API_KEY, etc.)
# These are filtered from LLM's bash subprocess by env-sanitizer extension
echo ">>> Decoding SECRETS..."
if [ -n "$SECRETS" ]; then
    echo "SECRETS variable is set (length: ${#SECRETS})"
    SECRETS_JSON=$(echo "$SECRETS" | base64 -d)
    if [ $? -eq 0 ]; then
        echo "Successfully decoded SECRETS from base64"
        SECRETS_KEYS=$(echo "$SECRETS_JSON" | jq -r 'keys | .[]' 2>/dev/null || echo "")
        echo "Found SECRETS keys: ${SECRETS_KEYS}"
        eval $(echo "$SECRETS_JSON" | jq -r 'to_entries | .[] | "export \(.key)=\"\(.value)\""')
        export SECRETS="$SECRETS_JSON"  # Keep decoded for extension to parse
        echo "✓ Exported SECRETS variables"
    else
        echo "ERROR: Failed to decode SECRETS from base64"
        exit 1
    fi
else
    echo "WARNING: SECRETS variable is empty or not set"
fi
echo ""

# Export LLM_SECRETS (base64 JSON) as flat env vars
# These are NOT filtered - LLM can access these (browser logins, skill API keys, etc.)
echo ">>> Exporting LLM_SECRETS..."
if [ -n "$LLM_SECRETS" ]; then
    echo "LLM_SECRETS variable is set (length: ${#LLM_SECRETS})"
    LLM_SECRETS_JSON=$(echo "$LLM_SECRETS" | base64 -d)
    if [ $? -eq 0 ]; then
        echo "Successfully decoded LLM_SECRETS from base64"
        LLM_SECRETS_KEYS=$(echo "$LLM_SECRETS_JSON" | jq -r 'keys | .[]' 2>/dev/null || echo "")
        echo "Found LLM_SECRETS keys: ${LLM_SECRETS_KEYS}"
        eval $(echo "$LLM_SECRETS_JSON" | jq -r 'to_entries | .[] | "export \(.key)=\"\(.value)\""')
        echo "✓ Exported LLM_SECRETS variables"
    else
        echo "ERROR: Failed to decode LLM_SECRETS from base64"
        exit 1
    fi
else
    echo "LLM_SECRETS variable is empty or not set (optional)"
fi
echo ""

# Git setup - derive identity from GitHub token
echo ">>> Configuring Git credentials..."
echo "Running: gh auth setup-git"
gh auth setup-git
if [ $? -eq 0 ]; then
    echo "✓ GitHub auth configured for git"
else
    echo "ERROR: Failed to setup GitHub auth for git"
    exit 1
fi

echo "Fetching GitHub user info..."
GH_USER_JSON=$(gh api user -q '{name: .name, login: .login, email: .email, id: .id}')
if [ $? -eq 0 ]; then
    echo "✓ Retrieved GitHub user info"
    echo "User JSON: ${GH_USER_JSON}"
else
    echo "ERROR: Failed to retrieve GitHub user info"
    exit 1
fi

GH_USER_NAME=$(echo "$GH_USER_JSON" | jq -r '.name // .login')
GH_USER_EMAIL=$(echo "$GH_USER_JSON" | jq -r '.email // "\(.id)+\(.login)@users.noreply.github.com"')
echo "GitHub user: ${GH_USER_NAME} <${GH_USER_EMAIL}>"

git config --global user.name "$GH_USER_NAME"
git config --global user.email "$GH_USER_EMAIL"
echo "✓ Git user configured"
echo ""

# Clone branch - with timeout and detailed logging
echo ">>> About to clone repository..."
echo "REPO_URL: ${REPO_URL}"
echo "BRANCH: ${BRANCH}"
echo "Destination: /job"
echo ""

if [ -n "$REPO_URL" ]; then
    echo ">>> Starting git clone with 60 second timeout..."
    GIT_CLONE_CMD="git clone --single-branch --branch \"$BRANCH\" --depth 1 \"$REPO_URL\" /job"
    echo "Command: ${GIT_CLONE_CMD}"
    echo "Executing at: $(date)"
    
    # Run git clone with timeout (60 seconds max)
    timeout 60 git clone --single-branch --branch "$BRANCH" --depth 1 "$REPO_URL" /job
    CLONE_EXIT_CODE=$?
    
    echo "Git clone exit code: ${CLONE_EXIT_CODE}"
    echo "Completed at: $(date)"
    
    if [ $CLONE_EXIT_CODE -eq 0 ]; then
        echo "✓ Clone completed successfully"
    elif [ $CLONE_EXIT_CODE -eq 124 ]; then
        echo "ERROR: Git clone timed out after 60 seconds!"
        echo "The clone command appears to be hanging."
        exit 1
    else
        echo "ERROR: Git clone failed with exit code ${CLONE_EXIT_CODE}"
        exit 1
    fi
else
    echo "ERROR: No REPO_URL provided"
    exit 1
fi
echo ""

echo ">>> Changing to /job directory..."
cd /job
if [ $? -eq 0 ]; then
    echo "✓ Successfully changed to /job"
    echo "Current directory: $(pwd)"
else
    echo "ERROR: Failed to change to /job directory"
    exit 1
fi
echo ""

# Create temp directory for agent use (gitignored via tmp/)
echo ">>> Creating temporary directory..."
mkdir -p /job/tmp
echo "✓ Created /job/tmp"
echo ""

# Symlink pi-skills into .pi/skills/ so Pi discovers them
echo ">>> Setting up Pi skills..."
ln -sf /pi-skills/brave-search /job/.pi/skills/brave-search
echo "✓ Symlinked brave-search skill"
echo ""

# Setup logs
LOG_DIR="/job/logs/${JOB_ID}"
echo ">>> Setting up job logs directory..."
echo "Log directory: ${LOG_DIR}"
mkdir -p "${LOG_DIR}"
echo "✓ Created log directory"
echo ""

# 1. Build system prompt from operating_system MD files
echo ">>> Building system prompt from operating_system files..."
SYSTEM_FILES=("SOUL.md" "AGENT.md")
> /job/.pi/SYSTEM.md
for i in "${!SYSTEM_FILES[@]}"; do
    FILE="/job/operating_system/${SYSTEM_FILES[$i]}"
    echo "  - Adding ${FILE}"
    if [ -f "$FILE" ]; then
        cat "$FILE" >> /job/.pi/SYSTEM.md
        if [ "$i" -lt $((${#SYSTEM_FILES[@]} - 1)) ]; then
            echo -e "\n\n" >> /job/.pi/SYSTEM.md
        fi
    else
        echo "    WARNING: File not found: ${FILE}"
    fi
done
echo "✓ System prompt built"
echo ""

# Check for job description
JOB_MD="/job/logs/${JOB_ID}/job.md"
echo ">>> Checking for job description..."
echo "Looking for: ${JOB_MD}"
if [ -f "${JOB_MD}" ]; then
    echo "✓ Found job.md"
    echo "Job file size: $(wc -c < "${JOB_MD}") bytes"
else
    echo "ERROR: job.md not found at ${JOB_MD}"
    exit 1
fi
echo ""

echo ">>> Starting Pi agent..."
PROMPT="

# Your Job

$(cat /job/logs/${JOB_ID}/job.md)"

MODEL_FLAGS=""
if [ -n "$MODEL" ]; then
    MODEL_FLAGS="--provider anthropic --model $MODEL"
    echo "Using custom model: $MODEL"
else
    echo "Using default Pi model"
fi

echo "Running Pi agent with session dir: ${LOG_DIR}"
echo "Started at: $(date)"
pi $MODEL_FLAGS -p "$PROMPT" --session-dir "${LOG_DIR}"
PI_EXIT_CODE=$?
echo "Pi agent completed with exit code: ${PI_EXIT_CODE}"
echo "Completed at: $(date)"
echo ""

# 2. Commit changes + logs
echo ">>> Committing changes..."
echo "Current directory: $(pwd)"
echo "Staging all changes..."
git add -A
git add -f "${LOG_DIR}"
echo "Committing with message: thepopebot: job ${JOB_ID}"
git commit -m "thepopebot: job ${JOB_ID}" || true
GIT_COMMIT_EXIT=$?
echo "Git commit exit code: ${GIT_COMMIT_EXIT}"

echo "Pushing to origin..."
git push origin
GIT_PUSH_EXIT=$?
echo "Git push exit code: ${GIT_PUSH_EXIT}"
echo ""

# 3. Merge (pi has memory of job via session)
#if [ -n "$REPO_URL" ] && [ -f "/job/MERGE_JOB.md" ]; then
#    echo "MERGED"
#    pi -p "$(cat /job/MERGE_JOB.md)" --session-dir "${LOG_DIR}" --continue
#fi

# 5. Create PR (auto-merge handled by GitHub Actions workflow)
echo ">>> Creating Pull Request..."
gh pr create --title "thepopebot: job ${JOB_ID}" --body "Automated job" --base main || true
GH_PR_EXIT=$?
echo "GitHub PR creation exit code: ${GH_PR_EXIT}"
echo ""

# Cleanup
echo ">>> Cleanup..."
echo "Killing Chrome process (PID: ${CHROME_PID})..."
kill $CHROME_PID 2>/dev/null || true
if ! kill -0 $CHROME_PID 2>/dev/null; then
    echo "✓ Chrome process terminated"
else
    echo "WARNING: Chrome process still running, forcing kill..."
    kill -9 $CHROME_PID 2>/dev/null || true
fi
echo ""

echo "=========================================="
echo "✓ Done. Job ID: ${JOB_ID}"
echo "=========================================="
echo "Job completed at: $(date)"
