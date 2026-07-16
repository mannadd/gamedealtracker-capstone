# GameDealTracker — architecture review

## Architecture

EventBridge Scheduler (planned) and API Gateway (HTTP API, live) trigger a single Lambda function
(`python3.12`, `LabRole`). The function calls the CheapShark API for current game deals, reads its
runtime config from Secrets Manager, and writes results to DynamoDB. Downstream, S3 stores JSON
summaries and SNS publishes deal alerts.

## Decisions

1. **DynamoDB over RDS** — RDS wins on ad-hoc querying and joins, but it costs more when idle (cost).
2. **HTTP API Gateway over REST API Gateway** — REST API wins on request validation and API-key
   throttling, but costs more per request and adds latency (cost, performance).
3. **Secrets Manager over Lambda environment variables** — environment variables win on simplicity
   and zero extra cost, but aren't encrypted at rest and offer no rotation path (security).
4. **SNS over SES** — SES wins on richer HTML templates and verified sender identities, but it isn't
   enabled in the AWS Academy Learner Lab, so it can't be deployed in this environment at all
   (operational excellence, reliability).

## Note

EventBridge Scheduler is shown as planned; only the API Gateway trigger path is confirmed live.
S3 bucket ownership should be confirmed with the teammate handling that resource.
