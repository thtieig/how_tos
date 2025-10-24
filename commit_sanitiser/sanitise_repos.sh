#!/bin/bash

set -e

# Load configuration if it exists
[[ -f "config.sh" ]] && source "config.sh"

# Configuration (with defaults, can be overridden by config.sh)
REPLACEMENT_NAME="${REPLACEMENT_NAME:-Noname}"
REPLACEMENT_EMAIL="${REPLACEMENT_EMAIL:-dev@users.noreply.github.com}"
REPOS_FILE="${REPOS_FILE:-repos.txt}"
EMAILS_FILE="${EMAILS_FILE:-emails.txt}"
WORK_DIR="${WORK_DIR:-sanitise_workdir}"
LOG_FILE="${LOG_FILE:-sanitisation_log.txt}"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

# Check prerequisites
command -v git >/dev/null 2>&1 || { echo -e "${RED}git is required but not installed${NC}"; exit 1; }
command -v git-filter-repo >/dev/null 2>&1 || { 
    echo -e "${RED}git-filter-repo is required but not installed${NC}"
    echo "Install with: pip3 install git-filter-repo"
    exit 1
}

# Check required files exist
[[ ! -f "$REPOS_FILE" ]] && { echo -e "${RED}$REPOS_FILE not found${NC}"; exit 1; }
[[ ! -f "$EMAILS_FILE" ]] && { echo -e "${RED}$EMAILS_FILE not found${NC}"; exit 1; }
[[ ! -s "$EMAILS_FILE" ]] && { echo -e "${RED}$EMAILS_FILE is empty${NC}"; exit 1; }

# Create work directory
if [[ -d "$WORK_DIR" ]]; then
    echo -e "${YELLOW}Existing work dir '$WORK_DIR' found, removing...${NC}"
    rm -rf "$WORK_DIR"
fi
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Initialise log
echo "Sanitisation started: $(date)" > "../$LOG_FILE"

# Read emails to sanitise
mapfile -t EMAILS_TO_REMOVE < "../$EMAILS_FILE"
echo -e "${YELLOW}Emails to sanitise: ${#EMAILS_TO_REMOVE[@]}${NC}"
printf '%s\n' "${EMAILS_TO_REMOVE[@]}"

echo ""
echo -e "${YELLOW}Replacement identity:${NC}"
echo "Name: $REPLACEMENT_NAME"
echo "Email: $REPLACEMENT_EMAIL"
echo ""

# Build mailmap content
MAILMAP_CONTENT=""
for email in "${EMAILS_TO_REMOVE[@]}"; do
    # Trim whitespace
    email=$(echo "$email" | xargs)
    [[ -z "$email" ]] && continue
    MAILMAP_CONTENT+="$REPLACEMENT_NAME <$REPLACEMENT_EMAIL> <$email>"$'\n'
done

echo -e "${GREEN}Processing repositories...${NC}\n"

# Read repositories
mapfile -t REPOS < "../$REPOS_FILE"

for repo_url in "${REPOS[@]}"; do
    [[ -z "$repo_url" ]] && continue
    
    # Extract repo name from URL
    repo_name=$(basename "$repo_url" .git)
    
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}Processing: $repo_name${NC}"
    echo -e "${YELLOW}================================================${NC}"
    echo "Repository: $repo_name" >> "../$LOG_FILE"
    
    # Clone repository
    if [[ -d "$repo_name" ]]; then
        echo -e "${YELLOW}Directory exists, removing...${NC}"
        rm -rf "$repo_name"
    fi
    
    echo "Cloning $repo_url..."
    if ! git clone "$repo_url" "$repo_name" 2>&1 | tee -a "../$LOG_FILE"; then
        echo -e "${RED}Failed to clone $repo_name${NC}" | tee -a "../$LOG_FILE"
        continue
    fi
    
    cd "$repo_name"
    
    # Get default branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    echo "Default branch: $default_branch"
    
    # Check if there are any commits with target emails
    echo "Checking for target emails in commits..."
    found_emails=false
    for email in "${EMAILS_TO_REMOVE[@]}"; do
        email=$(echo "$email" | xargs)
        [[ -z "$email" ]] && continue
        if git log --all --pretty=format:"%ae %ce" | grep -q "$email"; then
            found_emails=true
            count=$(git log --all --pretty=format:"%ae %ce" | grep -c "$email" || true)
            echo "  Found $count occurrences of: $email"
        fi
    done
    
    if [[ "$found_emails" == "false" ]]; then
        echo -e "${GREEN}No target emails found in $repo_name, skipping...${NC}"
        echo "Status: No emails found, skipped" >> "../../$LOG_FILE"
        cd ..
        rm -rf "$repo_name"
        echo ""
        continue
    fi
    
    # Show before state
    echo -e "\n${YELLOW}BEFORE sanitisation:${NC}"
    echo "Sample of commits:"
    git log --all --pretty=format:"  %h | %an <%ae> | %cn <%ce> | %s" -n 5
    
    # Create mailmap file
    echo "$MAILMAP_CONTENT" > .mailmap-temp
    
    echo -e "\n${YELLOW}Applying git-filter-repo...${NC}"
    
    # Run git-filter-repo with mailmap
    if git filter-repo --mailmap .mailmap-temp --force --refs "$default_branch" 2>&1 | tee -a "../../$LOG_FILE"; then
        echo -e "${GREEN}Filter completed${NC}"
        
        # git-filter-repo removes the remote, need to check the local branch only
        # and exclude replaced refs
        
        # Show after state (only the rewritten branch)
        echo -e "\n${YELLOW}AFTER sanitisation:${NC}"
        echo "Sample of commits:"
        git log "$default_branch" --pretty=format:"  %h | %an <%ae> | %cn <%ce> | %s" -n 5
        
        # Verification - check only the rewritten branch, not replaced refs
        echo -e "\n${YELLOW}Verifying sanitisation...${NC}"
        failed_verification=false
        for email in "${EMAILS_TO_REMOVE[@]}"; do
            email=$(echo "$email" | xargs)
            [[ -z "$email" ]] && continue
            if git log "$default_branch" --pretty=format:"%ae %ce" | grep -q "$email"; then
                echo -e "${RED}ERROR: Email still found after sanitisation: $email${NC}"
                failed_verification=true
            fi
        done
        
        if [[ "$failed_verification" == "true" ]]; then
            echo -e "${RED}VERIFICATION FAILED for $repo_name${NC}"
            echo "Status: VERIFICATION FAILED" >> "../../$LOG_FILE"
            cd ..
            echo -e "${RED}Repository $repo_name NOT pushed due to verification failure${NC}"
            echo ""
            continue
        fi
        
        echo -e "${GREEN}✓ Verification passed - no target emails found${NC}"
        echo "Status: Sanitised and verified" >> "../../$LOG_FILE"
        
        # Ask for confirmation before push (unless AUTO_APPROVE is set)
        if [[ "${AUTO_APPROVE:-0}" == "1" ]]; then
            confirm="yes"
            echo -e "\n${GREEN}AUTO_APPROVE enabled - pushing $repo_name${NC}"
        else
            echo -e "\n${YELLOW}Ready to force push $repo_name${NC}"
            read -p "Push this repository? [Y/n]: " confirm
            confirm=${confirm:-Y}  # Default to Y if empty (Enter pressed)
        fi
        
        if [[ "$confirm" =~ ^[Yy] ]]; then
            # Re-add remote (git-filter-repo removes it)
            git remote add origin "$repo_url" 2>/dev/null || git remote set-url origin "$repo_url"
            
            echo "Force pushing..."
            if git push origin "$default_branch" --force 2>&1 | tee -a "../../$LOG_FILE"; then
                echo -e "${GREEN}✓ Successfully pushed $repo_name${NC}"
                echo "Push: SUCCESS" >> "../../$LOG_FILE"
            else
                echo -e "${RED}✗ Failed to push $repo_name${NC}"
                echo "Push: FAILED" >> "../../$LOG_FILE"
            fi
        else
            echo -e "${YELLOW}Skipped pushing $repo_name${NC}"
            echo "Push: Skipped by user" >> "../../$LOG_FILE"
        fi
        
    else
        echo -e "${RED}git-filter-repo failed for $repo_name${NC}"
        echo "Status: Filter failed" >> "../../$LOG_FILE"
    fi
    
    cd ..
    echo ""
done

cd ..
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}All repositories processed${NC}"
echo -e "${GREEN}================================================${NC}"
echo -e "Check ${YELLOW}$LOG_FILE${NC} for details"
echo "Sanitisation completed: $(date)" >> "$LOG_FILE"
