# scouter

Service that handles event processing and storage.

## Usage

`Scouter` stores signals emitted by other services, and persist them in form of events. It also provides an API to query these events.

We use `organization_id`, `project_id` and `user_id` to identify the context of an event. This triplet is a unique identifier that defines a context.
Triplet values are optional and default to empty string. Default values for triplets are empty strings.
The context is invalid when all three values are empty strings.
