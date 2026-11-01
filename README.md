Zoho Analytics Stock Sync

This repository contains an automated pipeline that fetches stock data and synchronizes it with Zoho Analytics using GitHub Actions.

🚀 Overview

The workflow runs on a daily schedule to pull the latest stock data via a shell script and pushes the formatted data to Zoho Analytics using a Python script. It utilizes GitHub Actions for seamless orchestration, ensuring reliable execution without the need for manual intervention or local cron jobs.

📁 Repository Structure

pull_stock.sh: A shell script that retrieves raw stock data (utilizing jq for JSON processing).

push_to_analytics.py: A Python 3.10 script (using the requests library) that processes and uploads the data to Zoho Analytics.

.github/workflows/zoho_sync.yml: The GitHub Actions workflow file that automates the entire process.

⚙️ How It Works

The GitHub Actions workflow is designed to be triggered in two ways:

Scheduled Execution: Runs automatically on a daily cron schedule. It is configured to run at 05:02 AM IST (using the Asia/Kolkata timezone) with a slight offset to bypass top-of-the-hour server queue delays on GitHub.

Manual Execution: Can be triggered on-demand using the workflow_dispatch event directly from the GitHub Actions tab.

Workflow Steps:

Provisions a fresh ubuntu-latest environment and checks out the code.

Sets up Python 3.10.

Installs required system dependencies (jq) and Python packages (requests).

Executes pull_stock.sh to gather the stock data.

Runs push_to_analytics.py to push the gathered data to Zoho Analytics.

🔐 Setup & Configuration

If you are cloning or forking this repository, you will likely need to configure API keys and credentials for both your stock data provider and Zoho Analytics.

Add these as Repository Secrets in GitHub (Settings > Secrets and variables > Actions). Update your scripts to reference these secrets as environment variables. Common secrets might include:

ZOHO_CLIENT_ID

ZOHO_CLIENT_SECRET

ZOHO_REFRESH_TOKEN

STOCK_API_KEY

🏃‍♂️ Running Manually

To trigger a sync outside of the regular schedule:

Navigate to the Actions tab in the repository.

Select Zoho Stock Sync from the left-hand sidebar.

Click the Run workflow dropdown on the right side of the screen.

Click the green Run workflow button to execute the pipeline immediately.
