# Quard

A component that sits in front of the bridge and intercepts the incoming requests. Handles the authentication and authorization of the incoming requests before they are passed to the bridge.

## Example Request

```json
{
  "method": "PUT",
  "path": "/api/v1/command",
  "headers": {
    "Authorization": "Bearer <token>",
    "Content-Type": "application/json"
  },
    "body": {
        "command": "<command>",
        "requestee": "<requestee>",
        "requestor": "<requestor>"
    }
}
```

```shell
curl -X PUT \
  http://localhost:3000/api/v1/command \
    -H 'Authorization: Bearer AuthToken' \
    -H 'Content-Type: application/json' \
    -d '{"body": {
        "command": "command",
        "requestee": "requestee",
        "requestor": "requestor"
    }}'
```

