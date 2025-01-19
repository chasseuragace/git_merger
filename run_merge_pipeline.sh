#!/bin/bash

# Set script to exit on error
set -e

LOG_FILE="merge_pipeline.log"
echo "Starting Merge Pipeline Execution - $(date)" > $LOG_FILE

# Function to execute a script with logging
run_step() {
  local step_name="$1"
  local command="$2"

  echo "Executing: $step_name"
  echo "[$(date)] Running: $step_name" >> $LOG_FILE

  if eval "$command" >> $LOG_FILE 2>&1; then
    echo "SUCCESS: $step_name completed."
    echo "[$(date)] SUCCESS: $step_name completed." >> $LOG_FILE
  else
    echo "ERROR: $step_name failed. Check $LOG_FILE for details."
    echo "[$(date)] ERROR: $step_name failed." >> $LOG_FILE
    exit 1
  fi
}

# Run each step
run_step "Validating Merges" "./validate_merges.sh"
run_step "Merging Branches" "./branch-merger.sh"
run_step "Retrying Failed Merges" "./retry-failed-merges.sh"
run_step "Primary Conflict Analysis" "./primary_analysis.sh"
run_step "Running Dart Analysis" "dart analyze.dart"

echo "Merge Pipeline Execution Completed Successfully - $(date)" >> $LOG_FILE
echo "All steps completed successfully!"
