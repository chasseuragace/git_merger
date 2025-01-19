#!/bin/bash

# Configuration
DEVELOP_BRANCH="develop"
TARGET_BRANCH="S9_development"
LOG_FILE="output/operation_log.json"
MERGE_LOG_FILE="output/merge_results.json"

# Initialize merge log file
echo '{
  "execution_timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "merged_branches": [],
  "summary": {
    "total_merged": 0,
    "failed_merges": 0
  }
}' > "$MERGE_LOG_FILE"

# Function to log merge results
log_merge_result() {
    local branch="$1"
    local status="$2"
    local message="$3"
    
    jq --arg branch "$branch" \
       --arg status "$status" \
       --arg message "$message" \
       '.merged_branches += [{
           "name": $branch,
           "status": $status,
           "message": $message,
           "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
       }]' "$MERGE_LOG_FILE" > "$MERGE_LOG_FILE.tmp" && mv "$MERGE_LOG_FILE.tmp" "$MERGE_LOG_FILE"
}

# Function to update merge summary
update_merge_summary() {
    local total="$1"
    local failed="$2"
    
    jq --arg total "$total" \
       --arg failed "$failed" \
       '.summary.total_merged = ($total|tonumber) |
        .summary.failed_merges = ($failed|tonumber)' "$MERGE_LOG_FILE" > "$MERGE_LOG_FILE.tmp" && mv "$MERGE_LOG_FILE.tmp" "$MERGE_LOG_FILE"
}

# Ensure we're up to date
git fetch --all

# Create new integration branch
git checkout -b "$TARGET_BRANCH" "$DEVELOP_BRANCH"

# Initialize counters
total_merged=0
failed_merges=0

# Read successful branches from validation log and perform merges
successful_branches=$(jq -r '.branches[] | select(.status == "SUCCESS") | .name' "$LOG_FILE")

echo "Starting merges for successful branches..."

while IFS= read -r branch; do
    if [ -n "$branch" ]; then
        echo "Merging branch: $branch"
        if git merge --no-ff -m "Merge branch '$branch' into $TARGET_BRANCH" "$branch"; then
            ((total_merged++))
            log_merge_result "$branch" "SUCCESS" "Branch merged successfully"
        else
            ((failed_merges++))
            git merge --abort
            log_merge_result "$branch" "FAILED" "Merge failed unexpectedly"
        fi
    fi
done <<< "$successful_branches"

# Update final summary
update_merge_summary "$total_merged" "$failed_merges"

echo "Merge process completed. Check $MERGE_LOG_FILE for detailed results."
echo "Total branches merged: $total_merged"
echo "Failed merges: $failed_merges"

if [ "$failed_merges" -eq 0 ]; then
    echo "All merges completed successfully. The $TARGET_BRANCH branch is ready."
else
    echo "Some merges failed. Please check $MERGE_LOG_FILE for details."
fi