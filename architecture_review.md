# GameDealTracker — architecture review

## Architecture

EventBridge Scheduler (planned) and API Gateway (HTTP API, live) trigger a single Lambda function
(`python3.12`, `LabRole`). The function calls the CheapShark API for current game deals, reads its
runtime config from Secrets Manager, and writes results to DynamoDB. Downstream, S3 stores JSON
summaries and SNS publishes deal alerts.

```
 EventBridge Scheduler        API Gateway
 (Daily trigger, planned)     (HTTP API front door)
            \                       /
             \                     /
              v                   v
CheapShark API  -->      Lambda function       <--  Secrets Manager
                    (python3.12, LabRole)
                    /        |         \
                   v         v          v
              DynamoDB      S3          SNS
             (deals table) (JSON       (deal
                            summaries)  alerts)
```

## Decisions

| Chosen | Rejected | Rejected wins on | Pillar |
|---|---|---|---|
| DynamoDB | RDS | Ad-hoc queries and joins across tables | Cost |
| HTTP API Gateway | REST API Gateway | Built-in request validation, usage plans, API-key throttling | Cost, performance |
| Secrets Manager | Lambda environment variables | Simplicity, zero extra per-secret cost | Security |
| SNS | SES | Richer HTML email templates, verified sender identities | Operational excellence, reliability |

1. **DynamoDB over RDS** — RDS wins on ad-hoc querying and joins, but it costs more when idle (Cost Optimization).
2. **HTTP API Gateway over REST API Gateway** — REST API wins on request validation and API-key
   throttling, but costs more per request and adds latency (Cost Optimization, Performance Efficiency).
3. **Secrets Manager over Lambda environment variables** — environment variables win on simplicity
   and zero extra cost, but aren't encrypted at rest and offer no rotation path (Security).
4. **SNS over SES** — SES wins on richer HTML templates and verified sender identities, but it isn't
   enabled in the AWS Academy Learner Lab, so it can't be deployed in this environment at all
   (Operational Excellence, Reliability).

Pillar names per the AWS Well-Architected Framework: Operational Excellence, Security, Reliability,
Performance Efficiency, Cost Optimization, Sustainability
(https://docs.aws.amazon.com/wellarchitected/latest/framework/the-pillars-of-the-framework.html).

## Note

EventBridge Scheduler is shown as planned; only the API Gateway trigger path is confirmed live.
S3 bucket ownership (scratch/state bucket vs. summaries bucket) should be confirmed with the teammate
handling that resource before final submission.
