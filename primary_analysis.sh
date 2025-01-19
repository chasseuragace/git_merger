#!/bin/bash

# Configuration
DEVELOP_BRANCH="develop"
INPUT_FILE="output/retry_results.json"
CONFLICT_ANALYSIS_FILE="output/conflict_analysis.json"
TEMP_FILE="output/temp_stats.txt"
TEMP_AUTHORS_FILE="output/temp_authors.txt"

# Initialize analysis log file
echo '{
  "execution_timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",
  "conflict_analysis": [],
  "summary": {
    "total_conflicts": 0,
    "total_files": 0,
    "files_by_type": {},
    "most_conflicted_files": [],
    "involved_authors": []
  }
}' > "$CONFLICT_ANALYSIS_FILE"

# Create temp directory for stats
mkdir -p output
touch "$TEMP_FILE" "$TEMP_AUTHORS_FILE"

# Function to analyze a specific file conflict
analyze_file_conflict() {
    local branch="$1"
    local file="$2"
    
    local temp_dir=$(mktemp -d)
    git stash -q || true
    git checkout "$DEVELOP_BRANCH" 2>/dev/null || true
    git checkout -b "temp_analysis_${branch}" 2>/dev/null || true
    git merge "$branch" 2>/dev/null || true
    
    local conflict_content=""
    if [ -f "$file" ]; then
        conflict_content=$(grep -A 5 -B 5 "<<<<<<< HEAD" "$file" 2>/dev/null || echo "No conflict markers found")
    fi
    
    git merge --abort 2>/dev/null || true
    git checkout "$DEVELOP_BRANCH" 2>/dev/null || true
    git branch -D "temp_analysis_${branch}" 2>/dev/null || true
    git stash pop -q 2>/dev/null || true
    
    echo "$conflict_content"
}

# Function to get detailed file history
get_file_history() {
    local file="$1"
    local branch="$2"
    (
        git log --format="%h|%an|%ad|%s" "$DEVELOP_BRANCH" -- "$file" 2>/dev/null || echo ""
        git log --format="%h|%an|%ad|%s" "$branch" -- "$file" 2>/dev/null || echo ""
    ) | sort -u | head -n 5
}

# Function to get unique authors involved in conflicts
get_involved_authors() {
    local file="$1"
    local branch="$2"
    (
        git log --format="%an" "$DEVELOP_BRANCH" -- "$file" 2>/dev/null || echo ""
        git log --format="%an" "$branch" -- "$file" 2>/dev/null || echo ""
    ) | sort -u >> "$TEMP_AUTHORS_FILE"
}

# Function to log conflict analysis
log_conflict_analysis() {
    local branch="$1"
    local file="$2"
    local conflict_content="$3"
    local authors="$4"
    local history="$5"
    
    local file_type=""
    local dir_path=""
    
    if [ -n "$file" ]; then
        file_type=$(echo "$file" | awk -F. '{print $NF}')
        dir_path=$(dirname "$file")
        echo "$file_type" >> "$TEMP_FILE"
        echo "$file" >> "$TEMP_FILE.files"
    fi
    
    jq --arg branch "$branch" \
       --arg file "$file" \
       --arg type "$file_type" \
       --arg dir "$dir_path" \
       --arg content "$conflict_content" \
       --argjson authors "$(echo "$authors" | jq -R -s -c 'split("\n")[:-1]')" \
       --arg history "$history" \
       '.conflict_analysis += [{
           "branch": $branch,
           "file": $file,
           "file_type": $type,
           "directory": $dir,
           "conflict_content": $content,
           "involved_authors": $authors,
           "recent_changes": $history,
           "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
       }]' "$CONFLICT_ANALYSIS_FILE" > "$CONFLICT_ANALYSIS_FILE.tmp" && mv "$CONFLICT_ANALYSIS_FILE.tmp" "$CONFLICT_ANALYSIS_FILE"
}

# Process conflicts
while IFS= read -r branch_data; do
    branch=$(echo "$branch_data" | jq -r '.name')
    conflict_files=$(echo "$branch_data" | jq -r '.conflict_files')
    
    IFS=',' read -ra files <<< "$conflict_files"
    for file in "${files[@]}"; do
        [ -z "$file" ] && continue
        
        conflict_content=$(analyze_file_conflict "$branch" "$file")
        history=$(get_file_history "$file" "$branch")
        get_involved_authors "$file" "$branch"
        authors=$(sort -u "$TEMP_AUTHORS_FILE" | jq -R -s -c 'split("\n")[:-1]')
        
        log_conflict_analysis "$branch" "$file" "$conflict_content" "$authors" "$history"
    done

done < <(jq -c '.retry_attempts[] | select(.status == "FAILED")' "$INPUT_FILE")

# Calculate statistics
total_conflicts=$(wc -l < "$TEMP_FILE" || echo 0)
total_unique_files=$(sort -u "$TEMP_FILE.files" | wc -l || echo 0)
file_types=$(sort "$TEMP_FILE" | uniq -c | jq -R -s -c 'split("\n")[:-1] | map(select(length > 0)) | map(split(" ") | {(.[2]): .[1]}) | add')
most_conflicted=$(sort "$TEMP_FILE.files" | uniq -c | sort -nr | head -5 | awk '{$1=$1};1' | jq -R -s -c 'split("\n")[:-1]')
all_authors=$(sort -u "$TEMP_AUTHORS_FILE" | jq -R -s -c 'split("\n")[:-1]')

jq \
    --argjson total "$total_conflicts" \
    --argjson unique "$total_unique_files" \
    --argjson types "$file_types" \
    --argjson frequent "$most_conflicted" \
    --argjson authors "$all_authors" \
    '.summary.total_conflicts = $total |
     .summary.total_files = $unique |
     .summary.files_by_type = $types |
     .summary.most_conflicted_files = $frequent |
     .summary.involved_authors = $authors' \
    "$CONFLICT_ANALYSIS_FILE" > "$CONFLICT_ANALYSIS_FILE.tmp" && mv "$CONFLICT_ANALYSIS_FILE.tmp" "$CONFLICT_ANALYSIS_FILE"

# Cleanup temporary files
rm -f "$TEMP_FILE" "$TEMP_FILE.files" "$TEMP_AUTHORS_FILE"

echo "Detailed conflict analysis completed. Check $CONFLICT_ANALYSIS_FILE for results."
