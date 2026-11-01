import json
import os
import time
import urllib.parse
import requests

CLIENT_ID = os.getenv("ZOHO_CLIENT_ID")
CLIENT_SECRET = os.getenv("ZOHO_CLIENT_SECRET")
ANALYTICS_REFRESH_TOKEN = os.getenv("ZOHO_ANALYTICS_REFRESH_TOKEN")

WORKSPACE_ID = "220567000000006002"
VIEW_ID = "220567000006493830"
ORG_ID = "60012660339"

def get_zoho_access_token():
    if not all([CLIENT_ID, CLIENT_SECRET, ANALYTICS_REFRESH_TOKEN]):
        print("Error: Missing credentials in environment variables.")
        exit(1)

    url = "https://accounts.zoho.in/oauth/v2/token"
    data = {
        "grant_type": "refresh_token",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "refresh_token": ANALYTICS_REFRESH_TOKEN,
    }
    response = requests.post(url, data=data)
    return response.json().get("access_token")

def push_data_to_analytics():
    access_token = get_zoho_access_token()
    if not access_token:
        print("OAuth Authentication Failed.")
        exit(1)

    stock_file = "current_stock_warehouse.json"
    if not os.path.exists(stock_file):
        print("Stock JSON file not found.")
        exit(1)

    headers = {
        "Authorization": f"Zoho-oauthtoken {access_token}",
        "ZANALYTICS-ORGID": ORG_ID,
    }

    config = {
        "importType": "truncateadd",
        "fileType": "json",
        "autoIdentify": "true",
    }
    encoded_config = urllib.parse.quote(json.dumps(config))

    import_url = f"https://analyticsapi.zoho.in/restapi/v2/bulk/workspaces/{WORKSPACE_ID}/views/{VIEW_ID}/data?CONFIG={encoded_config}"

    with open(stock_file, "rb") as f:
        files = {"FILE": (stock_file, f, "application/json")}
        response = requests.post(import_url, headers=headers, files=files)

    print(f"Analytics API Response: {response.status_code} - {response.text}")

    if response.status_code not in (200, 202):
        exit(1)

    resp_json = response.json()
    job_id = resp_json.get("data", {}).get("jobId")

    if job_id:
        job_url = f"https://analyticsapi.zoho.in/restapi/v2/bulk/workspaces/{WORKSPACE_ID}/importjobs/{job_id}"
        for _ in range(24):
            time.sleep(5)
            job_resp = requests.get(job_url, headers=headers).json()
            job_code = job_resp.get("data", {}).get("jobCode")
            
            if str(job_code) == "1004":
                print(f"Import Completed Successfully: {json.dumps(job_resp)}")
                return
            elif str(job_code) in ("1003", "1005"):
                print(f"Import Job Failed: {json.dumps(job_resp)}")
                exit(1)
            print(f"Job in progress (code {job_code})...")

if __name__ == "__main__":
    push_data_to_analytics()
