# Your Public OpenRouter App Repository Name (Template)

This repository contains a template for a Node.js application integrated with OpenRouter, designed for quick, one-step deployment on a Ubuntu VPS.

The backend is pre-configured to use the `google/gemini-2.5-flash-preview:thinking` model via OpenRouter and listens for POST requests on `/generate`.

The frontend provides a basic, visually appealing template with a cute cat placeholder, ready for you to build upon.

**Prerequisites:**

*   A server (e.g., Ubuntu 22.04 VPS) with SSH access.
*   `sudo` privileges on the server.
*   A [OpenRouter API Key](https://openrouter.ai/keys).
*   Basic command-line access.
*   Internet connectivity to download packages and clone the repository.

**Automated Deployment Steps:**

1.  **SSH into your VPS:**
    ```bash
    ssh your_user@your_vps_ip
    ```

2.  **Download and run the deployment script:**

    This single command downloads the script directly from GitHub, makes it executable, and runs it. The script itself knows which repository to clone.

    ```bash
    curl -L https://raw.githubusercontent.com/Daniel-Farmer/Template/main/deploy_openrouter_app.sh -o deploy_openrouter_app.sh && chmod +x deploy_openrouter_app.sh && ./deploy_openrouter_app.sh
    # This command targets the 'main' branch of the 'Template' repository under 'Daniel-Farmer'.
    # If you rename the repo or use a different branch, update the URL accordingly.
    ```

    The script will:
    *   Prompt you ONLY for your **OpenRouter API Key**.
    *   Check for necessary software (Node.js, npm, PM2, git, unzip) and install them using `sudo apt` if missing.
    *   Clone this GitHub repository (`https://github.com/Daniel-Farmer/Template.git` branch `main`) into the `~/openrouter-app/` directory on your VPS.
    *   Create or update the `.env` file in the cloned directory with your API key and default port.
    *   Install the Node.js dependencies (`npm install`).
    *   Start your `server.js` application using PM2 under the name `openrouter-server`.
    *   Configure the UFW firewall to allow traffic on port 3000 (if UFW is active).

3.  **Complete the PM2 Startup Configuration (Crucial Manual Step!):**

    After the script finishes, it will print a command that looks something like `sudo env PATH=$PATH...`. **You MUST copy and paste this specific command and run it manually** into your terminal. This is a necessary step to ensure your application starts automatically every time your server reboots.

**Accessing the Application:**

Once the deployment script finishes and you have completed the manual PM2 startup step, your application should be running.

You can access the basic template page via your server's public IP address on port 3000, http://YOUR_VPS_IP_ADDRESS:3000

(Replace `YOUR_VPS_IP_ADDRESS` with your server's public IP)

**Managing the Application:**

The application code will be cloned into the `~/openrouter-app/` directory on the user's server.

*   **Project Directory:** `cd ~/openrouter-app/`
*   **Check Status:** `pm2 status`
*   **View Logs:** `pm2 logs openrouter-server` (or the process name defined in the script)
*   **Restart:** `pm2 restart openrouter-server`
*   **Stop:** `pm2 stop openrouter-server`
*   **Edit Code:** Navigate to the project directory (`cd ~/openrouter-app/`) and edit the files (e.g., `nano public/index.html`). After editing, restart the app (`pm2 restart openrouter-server`).
*   **Update Code from GitHub:** If you update the code in your public repository (and commit/push to the `main` branch), users can update their local copy by navigating to the project directory: `cd ~/openrouter-app/ && git pull origin main` (replace `main` with your branch), then reinstall dependencies if `package.json` changed (`npm install`), and finally restart the app (`pm2 restart openrouter-server`).

**Customization:**

*   Customize the frontend by editing the files in the `public/` directory.
*   Build out your UI in `public/script.js` to send prompts to the backend's `/generate` endpoint.
*   For production use with a domain and HTTPS, set up Nginx as a reverse proxy pointing to `http://localhost:3000` and update the `HTTP-Referer` header in `server.js`.
