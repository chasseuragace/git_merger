#!/bin/bash

# Get the name of the current branch
current_branch=$(git branch --show-current)

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    echo "You have uncommitted changes. Please commit or stash them before running this script."
    exit 1
fi

# Ensure the current branch was created from 'develop'
if ! git merge-base --is-ancestor develop $current_branch; then
    echo "Current branch was not created from 'develop'."
    exit 1
fi

# Display the summary of actions
echo "Summary of actions to be performed:"
echo "1. Ensure the local 'develop' branch is up to date."
echo "2. Merge 'develop' into the current branch ('$current_branch')."
echo "3. Push the updated '$current_branch' branch to the remote repository."

# Prompt the user for confirmation
read -p "Do you want to proceed with these actions? (y/n): " confirm
if [[ $confirm != "y" ]]; then
    echo "Operation cancelled."
    exit 1
fi

# Update local 'develop' branch
git checkout develop && git pull origin develop

# Switch back to the current branch and merge 'develop' into it
git checkout $current_branch && git merge develop

# Push the updated branch to the remote repository
git push origin $current_branch

echo "Successfully merged 'develop' into '$current_branch' and pushed to remote."