#!/bin/bash

# Usage: ./validate_merges.sh <develop_branch> <target_branch> <weeks_threshold>

# Read input arguments
develop_branch="$1"
target_branch="$2"
weeks_threshold="$3"

# Validate arguments
if [ -z "$develop_branch" ] || [ -z "$target_branch" ] || [ -z "$weeks_threshold" ]; then
    echo "Usage: $0 <develop_branch> <target_branch> <weeks_threshold>"
    exit 1
fi

# Compute the date threshold (current date - weeks_threshold weeks)
DATE_THRESHOLD=$(date -d "-$weeks_threshold weeks" +%Y-%m-%d)

# Configuration
OUTPUT_DIR="output"
LOG_FILE="$OUTPUT_DIR/operation_log.json"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Initialize JSON log file
echo '{
  "execution_timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "branches": [],
  "summary": {
    "total_branches": 0,
    "conflict_count": 0,
    "successful_merges": 0
  }
}' > "$LOG_FILE"

# Initialize counters
total_branches=0
conflict_count=0
successful_merges=0

# Function to add a branch entry to JSON log
add_branch_log() {
    local branch="$1"
    local status="$2"
    local conflict_files="$3"
    local message="$4"
    
    jq --arg branch "$branch" \
       --arg status "$status" \
       --arg conflict_files "$conflict_files" \
       --arg message "$message" \
       --arg last_commit "$(git log -1 --format=%cd --date=iso8601 $branch)" \
       '.branches += [{
           "name": $branch,
           "status": $status,
           "last_commit_date": $last_commit,
           "conflict_files": $conflict_files,
           "message": $message
       }]' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
}

# Function to update summary in JSON log
update_summary() {
    local total="$1"
    local conflicts="$2"
    local successful="$3"
    
    jq --arg total "$total" \
       --arg conflicts "$conflicts" \
       --arg successful "$successful" \
       '.summary.total_branches = ($total|tonumber) |
        .summary.conflict_count = ($conflicts|tonumber) |
        .summary.successful_merges = ($successful|tonumber)' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
}

# Ensure we're up to date
git fetch --all

# Create temporary branch for testing merges
git checkout -b "$target_branch" "$develop_branch"

# Get and process branches
while IFS= read -r branch; do
    if [ -n "$branch" ]; then
        last_commit_date=$(git log -1 --format=%cd --date=iso8601 "$branch")
        if [[ "$last_commit_date" > "$DATE_THRESHOLD" ]]; then
            ((total_branches++))
            
            # Try to merge
            if git merge --no-commit --no-ff "$branch" >/dev/null 2>&1; then
                ((successful_merges++))
                add_branch_log "$branch" "SUCCESS" "" "Branch can be merged cleanly"
                git reset --hard HEAD
            else
                ((conflict_count++))
                conflict_files=$(git diff --name-only --diff-filter=U | tr '\n' ',' | sed 's/,$//')
                add_branch_log "$branch" "CONFLICT" "$conflict_files" "Merge conflict detected"
                git merge --abort
            fi
        fi
    fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads/ --no-merged "$develop_branch")

# Update summary with final counts
update_summary "$total_branches" "$conflict_count" "$successful_merges"

# Cleanup
git checkout "$develop_branch"
git branch -D "$target_branch"

echo "Merge validation completed. Check $LOG_FILE for detailed results."
