#!/bin/bash
set -euo pipefail

# If there are quotation marks around the ip address, remove them
IP=${IP//[\'\"]/}
# Add *. wildcard to domain to encompass all subdomains as well
DOMAIN="*.$DOMAIN"

if [ -n "$IP" ]; then
    CHANGE_BATCH="{
        \"Comment\": \"Update A record for ${DOMAIN}\",
        \"Changes\": [{
            \"Action\": \"UPSERT\",
            \"ResourceRecordSet\": {
                \"Name\": \"${DOMAIN}.\",
                \"Type\": \"A\",
                \"TTL\": 300,
                \"ResourceRecords\": [{
                    \"Value\": \"${IP}\"}]
            }
        }]
    }"
    
    echo $CHANGE_BATCH > changedns.json
    RESULT=$(aws route53 change-resource-record-sets \
        --hosted-zone-id "/hostedzone/${ZONE_ID}" \
        --change-batch file://changedns.json)
    
    echo "✅ Route53 DNS record for '$DOMAIN' has been updated to '$IP'."
    echo "RESULT: $RESULT"

elif [ -n "$HOSTNAME" ]; then
    echo "🛠️ Updating Route53 DNS record for '$DOMAIN' to '$HOSTNAME'..."

else
    echo "❌ Timed out after $TIMEOUT seconds waiting for Ingress '$INGRESS_NAME' to receive an external IP."
    exit 1
fi
