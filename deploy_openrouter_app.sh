#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# **HARDCODED: Your GitHub Repository Details**
# The script knows where to get the code from.
GITHUB_USERNAME="Daniel-Farmer"
GITHUB_REPO_NAME="Template"
GITHUB_BRANCH="main" # Or 'master' if that's your branch

TARGET_DIR="$HOME/openrouter-app" # Consistent target directory
APP_PORT="3000" # Default port for the Node.js app
PM2_PROCESS_NAME="openrouter-server" # Fixed name for the PM2 process

# --- Introduction and User Input ---
echo "--- OpenRouter App Deployment Script ---"
echo "This script will set up your OpenRouter Node.js app template on this server by cloning the code from GitHub."
echo ""

# --- Get OpenRouter API Key from the user (This is the ONLY thing the script asks for) ---
read -p "Please enter your OpenRouter API Key: " OPENROUTER_API_KEY

if [ -z "$OPENROUTER_API_KEY" ]; then
  echo "Error: OpenRouter API Key cannot be empty. Exiting."
  exit 1
fi

# --- Check for sudo access ---
echo "Checking for sudo privileges..."
if ! sudo -v &> /dev/null; then
    echo "Error: You need sudo privileges to run this script for installing software and configuring firewall. Exiting."
    exit 1
fi
echo "Sudo privileges confirmed."

# --- Install Prerequisites (if not already installed) ---

echo "Installing necessary system packages (Node.js, npm, PM2, git, unzip)..."
echo "(This may take a few minutes)"

# Check and install Node.js and npm
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Node.js and npm not found. Installing Node.js v20..."
    # Add NodeSource repository for Node.js 20.x
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js and npm are already installed."
fi
node -v
npm -v

# Check and install PM2
if ! command -v pm2 &> /dev/null; then
    echo "PM2 not found. Installing PM2 globally..."
    sudo npm install -g pm2
else
    echo "PM2 is already installed."
fi
pm2 -v # Show PM2 version

# Check and install Git
if ! command -v git &> /dev/null; then
    echo "Git not found. Installing Git..."
    sudo apt install git -y
else
    echo "Git is already installed."
fi
git --version # Show Git version

# Check and install unzip (needed if the user just curls this script)
if ! command -v unzip &> /dev/null; then
    echo "unzip not found. Installing unzip..."
    sudo apt install unzip -y
else
     echo "unzip is already installed."
fi
unzip -v # Show unzip version


# --- Clone or Update the Repository ---
REPO_URL="https://github.com/$GITHUB_USERNAME/$GITHUB_REPO_NAME.git"

echo "Setting up repository from $REPO_URL branch $GITHUB_BRANCH in $TARGET_DIR..."

# Check if the target directory already exists and is a git repo
if [ -d "$TARGET_DIR" ] && [ -d "$TARGET_DIR/.git" ]; then
    echo "Directory $TARGET_DIR already exists and is a Git repository."
    echo "Attempting to pull latest changes..."
    cd "$TARGET_DIR"
    # Ensure we are on the correct branch before pulling
    git checkout "$GITHUB_BRANCH"
    if git pull origin "$GITHUB_BRANCH"; then
        echo "Git pull successful."
    else
        echo "Error: Git pull failed in $TARGET_DIR. Please resolve manually if needed. Continuing setup..."
        # Don't exit, maybe manual fixes allow setup to continue
    fi
elif [ -d "$TARGET_DIR" ]; then
     echo "Error: Directory $TARGET_DIR exists but is NOT a Git repository."
     echo "Please manually remove or rename this directory ('rm -rf $TARGET_DIR') and run the script again."
     exit 1
else
    # Directory does not exist, proceed with cloning
    # Ensure the parent directory exists if needed (e.g., $HOME)
    mkdir -p "$(dirname "$TARGET_DIR")" # Ensure parent dir exists
    # Clone into the target directory
    if git clone --depth 1 --branch "$GITHUB_BRANCH" "$REPO_URL" "$TARGET_DIR"; then
        echo "Git clone successful into $TARGET_DIR."
        cd "$TARGET_DIR"
    else
        echo "Error: Git clone failed from $REPO_URL branch $GITHUB_BRANCH into $TARGET_DIR. Exiting."
        # Clean up the potentially created but incomplete directory
        rm -rf "$TARGET_DIR" # Clean up if cloning failed
        exit 1
    fi
fi

# Ensure we are in the project directory for subsequent steps
cd "$TARGET_DIR"


# --- Create/Update .env file ---
# We still create this for consistency and if the user wants to run without PM2 later
echo "Creating or updating .env file in $TARGET_DIR/.env..."
cat << EOF_ENV > .env
OPENROUTER_API_KEY=$OPENROUTER_API_KEY
PORT=$APP_PORT
EOF_ENV
echo ".env file created/updated."

# --- Install Dependencies ---
echo "Installing Node.js dependencies (running npm install) in $TARGET_DIR..."
if [ -f package.json ]; then
    npm install
    echo "Dependencies installed."
else
    echo "Warning: package.json not found in $TARGET_DIR. Skipping npm install."
    echo "Please ensure your repository contains a package.json file."
fi

# --- Remove ecosystem.config.js if it exists from prior attempts ---
echo "Removing ecosystem.config.js if it exists from previous attempts..."
rm -f ecosystem.config.js || true
echo "Cleaned up ecosystem.config.js."

# --- PM2 Cleanup (Stop existing processes and clear save) ---
echo "Stopping all existing PM2 processes and clearing PM2 save file..."
# Stop all processes (ignore errors if none are running)
pm2 stop all || true
# Clear PM2's dump file which saves process list (ignore errors if file doesn't exist)
# This is located in the user's home/.pm2 directory
pm2 save --force 0 || true # force 0 instances saved
# Also explicitly kill the daemon just in case
pm2 kill || true
# Give it a moment
sleep 2
echo "PM2 processes stopped and save cleared."


# --- Start application with PM2 by passing environment variables ---
# Set the environment variables in the current shell before calling pm2
echo "Exporting environment variables for PM2..."
export OPENROUTER_API_KEY="$OPENROUTER_API_KEY"
export PORT="$APP_PORT"
# Node.js will pick these up via process.env using the dotenv library in server.js

echo "Starting application '$PM2_PROCESS_NAME' with PM2 from $TARGET_DIR by passing environment variables..."

# Use the start command targeting server.js directly
# PM2 should inherit the exported environment variables
# Use --interpreter and --interpreter-args for ES Modules with PM2
if [ -f server.js ]; then
    # Use --interpreter and --interpreter-args
    pm2 start server.js --name "$PM2_PROCESS_NAME" --cwd "$TARGET_DIR" --interpreter node --interpreter-args "--experimental-json-modules --no-warnings" -- "$@" # Pass script args
    echo "Application started with PM2."
else
    echo "Error: server.js not found in $TARGET_DIR. Cannot start application. Exiting."
    exit 1
fi


# --- Configure PM2 for Startup on Boot ---
echo "Configuring PM2 for startup on boot..."
# Generate the startup script command and tell the user to run it manually with sudo
# This step often requires user interaction or different sudo context/permissions than the script itself might have.
# Generate the command specifically for the user who ran the script (should be root in this /root case)
# Ensure the command is generated correctly for systemd
# Use 'whoami' and 'HOME' to get the current user's details correctly
PM2_STARTUP_CMD=$(env PATH=$PATH:/usr/bin /usr/local/lib/node_modules/pm2/bin/pm2 startup systemd -u $(whoami) --hp $HOME 2>&1) # Generate systemd startup command for current user

# Extract the actual sudo command from the output, looks like "sudo env PATH=..."
SUDO_STARTUP_CMD=$(echo "$PM2_STARTUP_CMD" | grep "sudo env PATH=")

echo ""
echo "------------------------------------------------------------------"
echo "--- MANUAL STEP REQUIRED ---"
echo ""
echo "To make the app start automatically on server reboots, you MUST run the following command manually *after* this script finishes:"
echo ""
# Print the extracted sudo command if found, otherwise print the full output and a generic fallback
if [ -n "$SUDO_STARTUP_CMD" ]; then
    echo "    $SUDO_STARTUP_CMD"
else
    echo "Could not automatically determine the exact sudo command. Please consult the PM2 documentation or try manually running:"
    echo "    sudo pm2 startup" # Simpler fallback, might work
    echo "Or the more specific command often seen:"
    echo "    sudo env PATH=\$PATH:/usr/bin /usr/local/lib/node_modules/pm2/bin/pm2 startup systemd -u \$(whoami) --hp \$HOME"
    echo ""
    echo "Full output from 'pm2 startup' was:"
    echo "$PM2_STARTUP_CMD"
fi
echo ""
echo "Copy and paste the command above into your terminal and press Enter."
echo "You may be asked for your password."
echo "------------------------------------------------------------------"
echo ""
# Save the PM2 process list NOW so the startup command has something to restore when it's run
# Save from the context of the target directory where the app is
(cd "$TARGET_DIR" && pm2 save)


# --- Configure UFW Firewall ---
echo "Checking and configuring UFW firewall..."
# Check if UFW command exists and if UFW is active
if command -v ufw &> /dev/null && sudo ufw status 2>&1 | grep -q "Status: active"; then
  echo "UFW is active. Allowing port $APP_PORT ($PM2_PROCESS_NAME)..."
  sudo ufw allow $APP_PORT/tcp
  sudo ufw reload
  echo "Firewall rule added. Current UFW status:"
  sudo ufw status --verbose # Show updated status
elif command -v ufw &> /dev/null; then
  echo "UFW command found, but UFW is not active. Skipping firewall configuration."
  echo "If you activate UFW later, remember to allow port $APP_PORT manually."
else
  echo "UFW command not found. Skipping firewall configuration."
  echo "If you use a firewall, ensure port $APP_PORT is open manually."
fi


# --- Completion Message ---
echo ""
echo "--- Deployment Complete ---"
echo "Your OpenRouter app template ($PM2_PROCESS_NAME) should now be running managed by PM2."
echo "The code is located at: $TARGET_DIR"
echo ""
echo "Next Steps:"
echo "1. **Crucial:** Run the manual 'pm2 startup' command printed above to enable boot persistence."
echo "2. Check the application status with: pm2 status"
echo "3. View application logs with: pm2 logs $PM2_PROCESS_NAME"
echo "4. Access the basic template page via your VPS IP address on port $APP_PORT (e.g., http://YOUR_VPS_IP:$APP_PORT)."
echo ""
echo "To edit the code, navigate to the project directory: cd $TARGET_DIR"
echo "To restart the app after code changes: pm2 restart $PM2_PROCESS_NAME"
echo ""
echo "Thank you for using the deployment script!"
