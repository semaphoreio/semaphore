#!/bin/bash

# Clean up server output files
rm -f /tmp/server_response.txt
rm -f /tmp/server_output.txt

# Start a fake Secrets server
nohup go run test/secrets_v1beta_server.go > /tmp/server_output.txt 2>&1 &

# Start the GRPC gateway
nohup env SECRETS_V1BETA_PUBLIC_GRPC_API_ENDPOINT=localhost:50051 /app/build/server >/tmp/gateway_output 2>&1 &

# sleep a bit, make sure that every server is running
sleep 18

secret='{ "metadata": { "name" : "secret-x" }, "data" : { "env_vars" : [ ] } }'

# send request to gateway
curl -X POST --data "$secret" -s -H "Authorization: Token xxx" -H "x-some-other-header: x-some-other-header-aaaa" "http://localhost:8080/api/v1beta/secrets" > /tmp/server_response.txt

server_output=$(cat /tmp/server_output.txt)
server_response=$(cat /tmp/server_response.txt)

echo "=== Output"
echo "$server_output"

echo "=== Response"
echo "$server_response"

echo "=== Gateway output"
cat /tmp/gateway_output

echo "=== Tests"

if [[ "$server_output" == *"Incomming Create Request"* ]]; then
    echo "Test passed: passes requests to the server"
else
    echo "Test failed: does not pass requests to the server"
fi

if [[ "$server_output" == *"Token xxx"* ]]; then
    echo "Test passed: passes the authorization header"
else
    echo "Test failed: does not pass the authorization header"
fi

if [[ "$server_output" == *"x-some-other-header-aaaa"* ]]; then
    echo "Test passed: passes random headers without modifications"
else
    echo "Test failed: does not pass random headers without modifications"
fi

if [[ "$server_output" != *"Incomming Create Request"* ]] || [[ "$server_output" != *"Token xxx"* ]] || [[ "$server_output" != *"x-some-other-header-aaaa"* ]]; then
    exit 1
fi
