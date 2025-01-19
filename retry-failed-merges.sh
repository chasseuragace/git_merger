#!/bin/bash

# Configuration
DEVELOP_BRANCH="develop"
TARGET_BRANCH="S9_development"
INPUT_FILE="output/merge_results.json"
RETRY_LOG_FILE="output/retry_results.json"

# Initialize retry log file
echo '{
  "execution_timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "retry_attempts": [],
  "summary": {
    "total_retries": 0,
    "successful_retries": 0,
    "failed_retries": 0
  }
}' > "$RETRY_LOG_FILE"

# Function to get list of authors involved in conflicts
get_conflict_authors() {
    local branch="$1"
    local conflict_file="$2"
    local authors=""
    
    # Get authors from develop branch
    develop_authors=$(git blame "$DEVELOP_BRANCH" -- "$conflict_file" 2>/dev/null | awk -F'(' '{print $2}' | awk '{print $1}' | sort -u | tr '\n' ',' | sed 's/,$//')
    
    # Get authors from feature branch
    feature_authors=$(git blame "$branch" -- "$conflict_file" 2>/dev/null | awk -F'(' '{print $2}' | awk '{print $1}' | sort -u | tr '\n' ',' | sed 's/,$//')
    
    # Combine unique authors
    authors="$develop_authors,$feature_authors"
    echo "$authors" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//'
}

# Function to log retry results
log_retry_result() {
    local branch="$1"
    local status="$2"
    local message="$3"
    local conflict_files="$4"
    local authors="$5"
    
    jq --arg branch "$branch" \
       --arg status "$status" \
       --arg message "$message" \
       --arg conflict_files "$conflict_files" \
       --arg authors "$authors" \
       '.retry_attempts += [{
           "name": $branch,
           "status": $status,
           "message": $message,
           "conflict_files": $conflict_files,
           "conflicting_authors": $authors,
           "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
       }]' "$RETRY_LOG_FILE" > "$RETRY_LOG_FILE.tmp" && mv "$RETRY_LOG_FILE.tmp" "$RETRY_LOG_FILE"
}

# Function to update retry summary
update_retry_summary() {
    local total="$1"
    local successful="$2"
    local failed="$3"
    
    jq --arg total "$total" \
       --arg successful "$successful" \
       --arg failed "$failed" \
       '.summary.total_retries = ($total|tonumber) |
        .summary.successful_retries = ($successful|tonumber) |
        .summary.failed_retries = ($failed|tonumber)' "$RETRY_LOG_FILE" > "$RETRY_LOG_FILE.tmp" && mv "$RETRY_LOG_FILE.tmp" "$RETRY_LOG_FILE"
}

# Ensure we're up to date
git fetch --all

# Create new integration branch if it doesn't exist
if ! git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
    git checkout -b "$TARGET_BRANCH" "$DEVELOP_BRANCH"
else
    git checkout "$TARGET_BRANCH"
fi

# Initialize counters
total_retries=0
successful_retries=0
failed_retries=0

# Read failed branches from previous merge results
failed_branches=$(jq -r '.merged_branches[] | select(.status == "FAILED") | .name' "$INPUT_FILE")

echo "Starting retry of failed merges..."

while IFS= read -r branch; do
    if [ -n "$branch" ]; then
        echo "Retrying merge for branch: $branch"
        ((total_retries++))
        
        # Try to merge
        conflict_files=""
        authors=""
        merge_output=$(git merge --no-ff "$branch" 2>&1)
        if [ $? -eq 0 ]; then
            ((successful_retries++))
            log_retry_result "$branch" "SUCCESS" "Branch merged successfully on retry" "" ""
        else
            ((failed_retries++))
            # Get list of conflicting files
            conflict_files=$(git diff --name-only --diff-filter=U | tr '\n' ',' | sed 's/,$//')
            
            # Get authors for each conflicting file
            all_authors=""
            for file in $(echo "$conflict_files" | tr ',' '\n'); do
                file_authors=$(get_conflict_authors "$branch" "$file")
                all_authors="$all_authors,$file_authors"
            done
            authors=$(echo "$all_authors" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/^,//;s/,$//')
            
            log_retry_result "$branch" "FAILED" "Merge conflicts persist" "$conflict_files" "$authors"
            git merge --abort
        fi
    fi
done <<< "$failed_branches"

# Update final summary
update_retry_summary "$total_retries" "$successful_retries" "$failed_retries"

echo "Retry process completed. Check $RETRY_LOG_FILE for detailed results."
echo "Total retries: $total_retries"
echo "Successful retries: $successful_retries"
echo "Failed retries: $failed_retries"

if [ "$failed_retries" -eq 0 ]; then
    echo "All retried merges completed successfully."
else
    echo "Some merges still have conflicts. Check $RETRY_LOG_FILE for details."
fi