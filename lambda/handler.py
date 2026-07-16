import json
import os
import time
import urllib.request
import urllib.error

import boto3

secretsmanager = boto3.client("secretsmanager")
dynamodb = boto3.resource("dynamodb")

CHEAPSHARK_URL = "https://www.cheapshark.com/api/1.0/deals?storeID=1&upperPrice=20&pageSize=5"
TABLE_NAME = os.environ.get("TABLE_NAME", "gamedeal-tracker-deals")


def get_secret_value():
    """Fetch the secret VALUE at runtime. Never hard-coded, never in env vars."""
    secret_name = os.environ.get("SECRET_NAME", "(not configured)")
    try:
        response = secretsmanager.get_secret_value(SecretId=secret_name)
        secret_dict = json.loads(response["SecretString"])
        return secret_name, secret_dict.get("api_key", "(no api_key key in secret)")
    except Exception as e:
        return secret_name, f"(error reading secret: {e})"


def call_cheapshark():
    """Call the CheapShark API. This is the one real external API call."""
    req = urllib.request.Request(CHEAPSHARK_URL, headers={"User-Agent": "GameDealTracker/1.0"})
    with urllib.request.urlopen(req, timeout=8) as resp:
        return json.loads(resp.read().decode("utf-8"))


def store_deals(deals):
    """Write each deal to DynamoDB, transformed into a simple item shape."""
    table = dynamodb.Table(TABLE_NAME)
    stored = []
    now = int(time.time())
    for deal in deals:
        item = {
            "deal_id": deal.get("dealID"),
            "title": deal.get("title"),
            "sale_price": deal.get("salePrice"),
            "normal_price": deal.get("normalPrice"),
            "savings_pct": deal.get("savings"),
            "fetched_at": now,
        }
        table.put_item(Item=item)
        stored.append(item["deal_id"])
    return stored


def lambda_handler(event, context):
    """
    Session 4 — real pipeline:
    1. Read secret VALUE from Secrets Manager at runtime.
    2. Call CheapShark API (external API, called once per invocation).
    3. Store the transformed results in DynamoDB.
    """
    secret_name, secret_value_preview = get_secret_value()

    try:
        deals = call_cheapshark()
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        body = {
            "message": "CheapShark API call failed.",
            "error": str(e),
            "secret_name_in_use": secret_name,
        }
        return {
            "statusCode": 502,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(body),
        }

    try:
        stored_ids = store_deals(deals)
    except Exception as e:
        body = {
            "message": "CheapShark call succeeded but DynamoDB write failed.",
            "error": str(e),
            "deal_count_fetched": len(deals),
            "secret_name_in_use": secret_name,
        }
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(body),
        }

    body = {
        "message": "Fetched CheapShark deals and stored them in DynamoDB.",
        "status": "success",
        "deal_count": len(stored_ids),
        "stored_deal_ids": stored_ids,
        "secret_name_in_use": secret_name,
        "secret_value_preview": secret_value_preview,
    }
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
