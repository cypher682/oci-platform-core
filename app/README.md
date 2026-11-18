# platform-api

Minimal Go service used to prove the delivery path end to end.

| Route | Purpose |
|---|---|
| `GET /health` | Liveness/readiness for OCI LB, Kubernetes probes and smoke tests |
| `GET /ready` | Readiness — returns 200 once the process accepts traffic |
| `GET /metrics` | Prometheus text: request count, uptime, build info |
| `GET /` | Service metadata |

Built as a static binary into `scratch`, running as UID 65532.

```bash
docker build --build-arg VERSION=$(git rev-parse --short HEAD) -t platform-api:local .
docker run --rm -p 8080:8080 platform-api:local
curl localhost:8080/health
```
