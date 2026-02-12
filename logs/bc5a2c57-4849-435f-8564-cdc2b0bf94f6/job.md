Add comprehensive debug logging to entrypoint.sh to diagnose why git clone is hanging.

TASKS:

1. Open `entrypoint.sh`

2. Add verbose/debug flags and logging:
   - Set `set -x` at the top (bash trace mode) to log every command
   - Add `echo` statements before and after each major step:
     * "Starting entrypoint.sh"
     * "Extracting Job ID from branch: {branch name}"
     * "Starting Chrome on port 9222..."
     * "Decoding SECRETS..."
     * "Exporting environment variables..."
     * "Configuring Git credentials..."
     * "About to clone: {REPO_URL} branch {BRANCH} into /job"
     * "Clone completed successfully"
     * "Starting Pi agent..."
   
3. Specifically for the git clone step:
   - Add `set -x` before the git clone command to see exactly what git is doing
   - Add timeout wrapper: `timeout 60 git clone ...` so it fails after 60 seconds instead of hanging forever
   - Log the git clone command itself before executing it
   - Log the exit code immediately after: `echo "Git clone exit code: $?"`

4. For Chrome startup:
   - Add logging to check if Chrome process actually started
   - Log the PID and port
   - Add a quick connectivity check (curl to localhost:9222) to verify Chrome is responsive

5. Add error handling:
   - If git clone fails, log the full error message and exit with clear error code
   - If Chrome fails to start, log that and exit immediately

6. Commit with message: "thepopebot: add debug logging to entrypoint.sh"

This will let us see exactly where the hang is happening in the next run.