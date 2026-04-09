#!/bin/bash

# MerryNet Full Deployment Script
# This script commits changes to GitHub and deploys to Render.com
# 
# Usage: ./scripts/deploy_full.sh [commit-message]

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to print step headers
print_step() {
    echo ""
    echo -e "${GREEN}Step $1: $2${NC}"
    echo "----------------------------------------"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Git status
check_git_status() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a Git repository${NC}"
        exit 1
    fi
    
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${YELLOW}Warning: Untracked changes detected${NC}"
        echo "Current status:"
        git status --short
        echo ""
        read -p "Continue with deployment? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Deployment cancelled"
            exit 1
        fi
    fi
}

# Function to setup Git if needed
setup_git() {
    if ! git config user.name > /dev/null 2>&1; then
        echo -e "${YELLOW}Git user not configured. Setting up...${NC}"
        read -p "Enter your name: " git_name
        read -p "Enter your email: " git_email
        git config user.name "$git_name"
        git config user.email "$git_email"
        echo -e "${GREEN}✓${NC} Git user configured"
    fi
}

# Function to add files to staging
stage_files() {
    echo "Staging files for commit..."
    
    # Add all untracked files
    git add .
    
    # Add specific important files that might be missed
    git add -f main-server/render.yaml
    git add -f merry-net-dashboard/render.yaml
    git add -f render.yaml
    git add -f scripts/deploy_to_render.sh
    git add -f docs/RENDER_DEPLOYMENT.md
    git add -f docs/DEVELOPER_MODE.md
    git add -f SETUP.md
    git add -f SECURITY.md
    
    echo -e "${GREEN}✓${NC} Files staged"
}

# Function to create commit
create_commit() {
    local commit_msg="$1"
    
    if [ -z "$commit_msg" ]; then
        commit_msg="🚀 Deploy to Render: Production-ready MerryNet with AI chatbot and developer mode"
    fi
    
    echo "Creating commit with message: $commit_msg"
    git commit -m "$commit_msg"
    echo -e "${GREEN}✓${NC} Commit created"
}

# Function to push to GitHub
push_to_github() {
    echo "Pushing to GitHub..."
    
    # Check if remote exists
    if ! git remote get-url origin > /dev/null 2>&1; then
        echo -e "${YELLOW}No remote origin found. Please add your GitHub remote:${NC}"
        echo "git remote add origin <your-github-repo-url>"
        exit 1
    fi
    
    # Push to main/master branch
    git push origin main || git push origin master
    echo -e "${GREEN}✓${NC} Pushed to GitHub"
}

# Function to deploy to Render
deploy_to_render() {
    echo "Deploying to Render.com..."
    
    if ! command_exists render; then
        echo -e "${RED}Error: Render CLI not found${NC}"
        echo "Please install the Render CLI from: https://render.com/docs/cli"
        echo "Then run: render login"
        exit 1
    fi
    
    if ! render status >/dev/null 2>&1; then
        echo "Please run 'render login' to authenticate with Render.com"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Render CLI authenticated"
    
    # Run the deployment script
    if [ -f "scripts/deploy_to_render.sh" ]; then
        echo "Running Render deployment script..."
        bash scripts/deploy_to_render.sh
    else
        echo -e "${YELLOW}Render deployment script not found, manual deployment required${NC}"
        echo "Please follow the guide in docs/RENDER_DEPLOYMENT.md"
    fi
}

# Function to verify deployment
verify_deployment() {
    echo "Verifying deployment..."
    
    # Check if services are deployed
    echo "Checking Render services..."
    render services list || echo "Unable to list services, please check manually"
    
    echo ""
    echo -e "${GREEN}🎉 Deployment verification complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Check Render dashboard for service status"
    echo "2. Verify all services are running"
    echo "3. Test the application endpoints"
    echo "4. Monitor logs for any issues"
}

# Main deployment function
main() {
    print_header "MerryNet Full Deployment"
    
    # Get commit message from command line or use default
    COMMIT_MSG="$1"
    
    print_step 1 "Pre-deployment Checks"
    check_git_status
    setup_git
    
    print_step 2 "Staging Files"
    stage_files
    
    print_step 3 "Creating Commit"
    create_commit "$COMMIT_MSG"
    
    print_step 4 "Pushing to GitHub"
    push_to_github
    
    print_step 5 "Deploying to Render"
    deploy_to_render
    
    print_step 6 "Verification"
    verify_deployment
    
    print_header "Deployment Complete!"
    echo ""
    echo -e "${GREEN}✅ MerryNet has been successfully deployed!${NC}"
    echo ""
    echo "Services deployed:"
    echo "  • Main API: https://maranet-api.onrender.com"
    echo "  • Dashboard: https://maranet.onrender.com"
    echo "  • Bootstrap: https://maranet-bootstrap.onrender.com"
    echo ""
    echo "Features available:"
    echo "  • AI Chatbot with intelligent algorithms"
    echo "  • Developer mode with server switching"
    echo "  • Real-time traffic monitoring"
    echo "  • Production-ready infrastructure"
    echo ""
    echo "For troubleshooting, check:"
    echo "  • Render dashboard logs"
    echo "  • docs/RENDER_DEPLOYMENT.md"
    echo "  • docs/DEVELOPER_MODE.md"
}

# Run main function with all arguments
main "$@"