# Your Public OpenRouter App Repository Name

This repository contains a template for a Node.js application integrated with OpenRouter, designed for quick, one-step deployment on a Ubuntu VPS.

The backend is pre-configured to use the `google/gemini-2.5-flash-preview:thinking` model via OpenRouter and listens for POST requests on `/generate`.

**Prerequisites:**

*   A server (e.g., Ubuntu 22.04 VPS) with SSH access.
*   `sudo` privileges on the server.
*   A [OpenRouter API Key](https://openrouter.ai/keys).
*   Basic command-line access.

**Automated Deployment Steps:**

1.  **SSH into your VPS:**
    ```bash
    ssh your_user@your_vps_ip
    ```

2.  **Download and run the deployment script:**

    This single command downloads the script directly from GitHub, makes it executable, and runs it.

    ```bash
    curl -L https://raw.githubusercontent.com/Daniel-Farmer/Template/main/deploy_openrouter_app.sh -o deploy_openrouter_app.sh && chmod +x deploy_openrouter_app.sh && ./deploy_openrouter_app.sh
    # Replace 'YOUR_USERNAME', 'YOUR_REPO_NAME', and 'main' with your GitHub details.
    # Replace 'main' with 'master' if that is your default branch name.
    ```

    The script will prompt you to enter your GitHub username, repository name, branch, and your OpenRouter API Key. It will then install necessary software, clone the repository into `~/openrouter-app/`, install Node.js dependencies, start the application using PM2, and configure the UFW firewall (if active).

3.  **Complete the PM2 Startup Configuration (Important!):**

    After the script finishes, it will print a command that looks something like `sudo env PATH=$PATH...`. **You MUST copy and paste this specific command and run it manually** into your terminal. This is a necessary step to ensure your application starts automatically every time your server reboots.

**Accessing the Application:**

Once the deployment script finishes and you have completed the manual PM2 startup step, your application should be running.

You can access the basic template page via your server's public IP address on port 3000:
http://YOUR_VPS_IP_ADDRESS:3000

(Replace `YOUR_VPS_IP_ADDRESS` with your server's public IP)

**Managing the Application:**

The application code will be cloned into the `~/openrouter-app/` directory on the user's server.

*   **Project Directory:** `cd ~/openrouter-app/`
*   **Check Status:** `pm2 status`
*   **View Logs:** `pm2 logs openrouter-blank-app` (or the project name specified in package.json)
*   **Restart:** `pm2 restart openrouter-blank-app`
*   **Stop:** `pm2 stop openrouter-blank-app`
*   **Edit Code:** Navigate to the project directory (`cd ~/openrouter-app/`) and edit the files (e.g., `nano public/index.html`). After editing, restart the app (`pm2 restart openrouter-blank-app`).
*   **Update Code from GitHub:** If you update the code in your public repository, users can pull changes from within the project directory: `cd ~/openrouter-app/ && git pull origin main` (replace `main` with your branch), then reinstall dependencies if package.json changed (`npm install`), and finally restart the app (`pm2 restart openrouter-blank-app`).

**Customization:**

*   Customize the frontend by editing `~/openrouter-app/public/index.html`, `~/openrouter-app/public/style.css`, and `~/openrouter-app/public/script.js`.
*   Modify the backend behavior by editing `~/openrouter-app/server.js`.
*   For production use with a domain and HTTPS, set up Nginx as a reverse proxy pointing to `http://localhost:3000` and update the `HTTP-Referer` header in `server.js`.
