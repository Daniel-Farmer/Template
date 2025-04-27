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
if ! command -v node &> /dev/null || ! command -v npm &> /dev-null; then
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


# --- Determine Project Name for PM2 ---
# Get the name from package.json if it exists, fallback to repo name
PROJECT_NAME="$GITHUB_REPO_NAME" # Default to repo name
if [ -f package.json ]; then
    # Use node to parse package.json and get the name field
    # Handle potential errors during JSON parsing
    JSON_NAME=$(node -p "try { console.log(require('./package.json').name) } catch(e) { process.exit(1) }" 2>/dev/null)
    if [ -n "$JSON_NAME" ]; then # Check if JSON_NAME is not empty
        PROJECT_NAME="$JSON_NAME"
        echo "Using project name '$PROJECT_NAME' from package.json for PM2."
    else
        echo "Could not read project name from package.json. Using default '$PROJECT_NAME' for PM2."
    fi
fi

# --- Start application with PM2 ---
echo "Starting application '$PROJECT_NAME' with PM2 from $TARGET_DIR..."
# Kill any existing PM2 process with the same name
pm2 delete "$PROJECT_NAME" 2>/dev/null || true
# Start the app using node interpreter with necessary flags for ES modules
# REMOVED: --force-compat
if [ -f server.js ]; then
    pm2 start server.js --name "$PROJECT_NAME" --cwd "$TARGET_DIR" --interpreter node --interpreter-args "--experimental-json-modules --no-warnings" -- "$@" # Pass script args
    echo "Application started with PM2."
else
    echo "Error: server.js not found in $TARGET_DIR. Cannot start application. Exiting."
    exit 1
fi


# --- Configure PM2 for Startup on Boot ---
echo "Configuring PM2 for startup on boot..."
# Generate the startup script command and tell the user to run it manually with sudo
# This step often requires user interaction or different sudo context/permissions than the script itself might have.
# Generate the command specifically for the user who ran the script
# Ensure the command is generated correctly for systemd
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
# Save the PM2 process list so the startup command has something to restore
# Save from the context of the target directory where the app is
(cd "$TARGET_DIR" && pm2 save)


# --- Configure UFW Firewall ---
echo "Checking and configuring UFW firewall..."
# Check if UFW command exists and if UFW is active
if command -v ufw &> /dev/null && sudo ufw status 2>&1 | grep -q "Status: active"; then
  echo "UFW is active. Allowing port $APP_PORT ($PROJECT_NAME)..."
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
echo "Your OpenRouter app template ($PROJECT_NAME) should now be running managed by PM2."
echo "The code is located at: $TARGET_DIR"
echo ""
echo "Next Steps:"
echo "1. **Crucial:** Run the manual 'pm2 startup' command printed above to enable boot persistence."
echo "2. Check the application status with: pm2 status"
echo "3. View application logs with: pm2 logs $PROJECT_NAME"
echo "4. Access the basic template page via your VPS IP address on port $APP_PORT (e.g., http://YOUR_VPS_IP:$APP_PORT)."
echo "5. To edit the code, navigate to the project directory: cd $TARGET_DIR"
echo "6. Edit the frontend files (public/index.html, public/style.css, public/script.js) and the backend file (server.js) in $TARGET_DIR."
echo "7. After editing code, restart the app: pm2 restart $PROJECT_NAME"
echo "8. If you want to update the code from GitHub later: cd $TARGET_DIR && git pull origin $GITHUB_BRANCH && npm install (if package.json changed) && pm2 restart $PROJECT_NAME"
echo "9. For production access via a public domain and HTTPS, set up Nginx as a reverse proxy and update the 'HTTP-Referer' header in 'server.js'."
echo ""
echo "Thank you for using the deployment script!"
