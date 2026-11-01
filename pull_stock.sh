#!/bin/bash
set -e
shopt -s nullglob

if [ -z "$ZOHO_CLIENT_ID" ] || [ -z "$ZOHO_CLIENT_SECRET" ] || [ -z "$ZOHO_INVENTORY_REFRESH_TOKEN" ]; then
  echo "Error: Missing Zoho credentials in environment variables."
  exit 1
fi

ORG_ID="60012618957"
BASE_URL="https://www.zohoapis.in/inventory/v1"

rm -rf /tmp/zoho_wh_pages /tmp/zoho_ids.txt /tmp/zoho_batches.txt && mkdir -p /tmp/zoho_wh_pages
touch /tmp/zoho_ids.txt

TOKEN_RESPONSE=$(curl -sS -X POST "https://accounts.zoho.in/oauth/v2/token" \
  -d "grant_type=refresh_token" \
  -d "client_id=$ZOHO_CLIENT_ID" \
  -d "client_secret=$ZOHO_CLIENT_SECRET" \
  -d "refresh_token=$ZOHO_INVENTORY_REFRESH_TOKEN")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r ".access_token // empty")
if [ -z "$ACCESS_TOKEN" ]; then
  echo "OAuth Error:" && echo "$TOKEN_RESPONSE" | jq .
  exit 1
fi

echo "Step 1/2: Finding active in-stock item IDs..."
PAGE=1
while true; do
  RESPONSE=$(curl -sS -G "$BASE_URL/items" \
    -H "Authorization: Zoho-oauthtoken $ACCESS_TOKEN" \
    --data-urlencode "organization_id=$ORG_ID" \
    --data-urlencode "filter_by=Status.Active" \
    --data-urlencode "sort_column=stock_on_hand" \
    --data-urlencode "sort_order=D" \
    --data-urlencode "page=$PAGE" \
    --data-urlencode "per_page=200")

  TOTAL_ON_PAGE=$(echo "$RESPONSE" | jq ".items | length")
  [ "$TOTAL_ON_PAGE" -eq 0 ] && break

  PAGE_IDS=$(echo "$RESPONSE" | jq -r ".items[] | select((.stock_on_hand // 0) > 0) | .item_id")
  if [ -z "$PAGE_IDS" ]; then
    break
  fi

  echo "$PAGE_IDS" >> /tmp/zoho_ids.txt
  IN_STOCK_COUNT=$(echo "$PAGE_IDS" | wc -l | tr -d " ")
  echo "  Scan Page $PAGE: $IN_STOCK_COUNT in-stock IDs found"

  if [ "$IN_STOCK_COUNT" -lt "$TOTAL_ON_PAGE" ] || [ "$TOTAL_ON_PAGE" -lt 200 ]; then
    break
  fi

  PAGE=$((PAGE + 1))
  sleep 0.65
done

TOTAL_IDS=$(wc -l < /tmp/zoho_ids.txt | tr -d " ")
echo "Found $TOTAL_IDS in-stock items. Step 2/2: Pulling all warehouse stock (100 items/call)..."

if [ "$TOTAL_IDS" -gt 0 ]; then
  xargs -n 100 < /tmp/zoho_ids.txt | tr " " "," > /tmp/zoho_batches.txt

  BATCH_NUM=1
  while IFS= read -r COMMA_IDS; do
    [ -z "$COMMA_IDS" ] && continue
    FILE_BATCH=$(printf "%05d" "$BATCH_NUM")

    DETAIL_RESP=$(curl -sS -G "$BASE_URL/itemdetails" \
      -H "Authorization: Zoho-oauthtoken $ACCESS_TOKEN" \
      --data-urlencode "organization_id=$ORG_ID" \
      --data-urlencode "item_ids=$COMMA_IDS")

    echo "$DETAIL_RESP" | jq '[
      .items[] as $item |
      ($item.warehouses // [])[] |
      select((.warehouse_stock_on_hand // 0) > 0) |
      {
        item_id: ($item.item_id | tostring),
        item_name: $item.name,
        sku: ($item.sku // ""),
        warehouse_id: (.warehouse_id | tostring),
        warehouse_name: (.warehouse_name // ""),
        warehouse_stock_on_hand: (.warehouse_stock_on_hand // 0),
        warehouse_available_stock: (.warehouse_available_stock // 0),
        warehouse_actual_available_stock: (.warehouse_actual_available_stock // 0),
        warehouse_committed_stock: (.warehouse_committed_stock // 0),
        warehouse_actual_committed_stock: (.warehouse_actual_committed_stock // 0),
        warehouse_available_for_sale_stock: (.warehouse_available_for_sale_stock // 0),
        warehouse_actual_available_for_sale_stock: (.warehouse_actual_available_for_sale_stock // 0)
      }
    ]' > "/tmp/zoho_wh_pages/batch_${FILE_BATCH}.json"

    ROWS=$(jq "length" "/tmp/zoho_wh_pages/batch_${FILE_BATCH}.json")
    echo "  Batch $BATCH_NUM: extracted $ROWS warehouse stock rows"
    BATCH_NUM=$((BATCH_NUM + 1))
    sleep 0.65
  done < /tmp/zoho_batches.txt
fi

FILES=(/tmp/zoho_wh_pages/batch_*.json)
if [ ${#FILES[@]} -gt 0 ]; then
  jq -s "add" "${FILES[@]}" > current_stock_warehouse.json
else
  echo "[]" > current_stock_warehouse.json
fi
rm -rf /tmp/zoho_wh_pages /tmp/zoho_ids.txt /tmp/zoho_batches.txt

echo "Done! Total warehouse-item rows saved: $(jq "length" current_stock_warehouse.json)"
