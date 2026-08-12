# LLM Infrastructure & MLOps Platform

End-to-end Kubernetes-based deployment platform for serving Open-Source LLMs with automated CI/CD, IaC, and Observability.

---

## Day 1: Infrastructure & Local Environment Baseline

### Accomplished

- [x] AWS Billing Guardrails configured with 10 alert caps
- [x] AWS CLI v2 configured with non-root IAM user (`yash-IAM-Admin`)
- [x] Local toolchain verified:
  - Docker v29
  - kubectl v1.36
  - kind v0.22
  - Terraform v1.15
- [x] Local 2-node Kubernetes cluster created using `kind`
  - Cluster: `devops-ai-cluster`
- [x] Ollama local model serving verified

### Architectural Rationale & Design Patterns

- **Non-root AWS IAM Access**: Used a dedicated IAM administrator identity instead of the AWS root account to reduce operational and security risk.

- **Local Kubernetes via kind**: Chosen to provide a reproducible multi-node Kubernetes environment without incurring cloud infrastructure costs during development.

- **Cost Guardrails**: AWS billing alerts were configured before beginning cloud infrastructure work to prevent unexpected resource consumption.

---

## Day 2: Containerized Ollama Deployment into `kind`

### Accomplished

- [x] Ollama containerized and deployed into the local `kind` cluster
- [x] Dedicated Kubernetes namespace configured for LLM serving
- [x] Persistent Volume Claim (`ollama-pvc`) created
- [x] Ollama model storage mounted at `/root/.ollama`
- [x] Init container implemented for automatic model bootstrap
- [x] `qwen2.5:0.5b` model configured for automatic download
- [x] Ollama serving container verified

### Architectural Rationale & Design Patterns

- **CPU-based Serving**: Retained Ollama GGUF quantized models on CPU to avoid GPU overhead and unnecessary infrastructure costs in local `kind` clusters.

- **Persistent Storage (`ollama-pvc`)**: Mounted a 5Gi PVC to `/root/.ollama` to decouple model-weight storage from pod lifecycles, eliminating unnecessary model re-downloads after pod restarts.

- **Init Container Bootstrap Pattern**: Introduced an `initContainer` named `model-puller` to verify Ollama readiness using `ollama list` and fetch `qwen2.5:0.5b` model weights before the primary serving container starts.

- **Container Lifecycle Separation**: Model initialization is isolated from the serving process, allowing the main Ollama container to start only after the required model artifacts are available.

---

## Day 3: Kubernetes Service Discovery & FastAPI Integration

### Accomplished

- [x] FastAPI application integrated with the Ollama backend
- [x] Kubernetes Service created for Ollama
- [x] FastAPI configured to communicate with Ollama through Kubernetes DNS
- [x] Hardcoded Pod IP addressing eliminated
- [x] Internal service communication established using the Kubernetes FQDN

### Architectural Rationale & Design Patterns

- **Kubernetes DNS-Based Service Discovery**: The FastAPI layer communicates with the Ollama backend using the Kubernetes CoreDNS domain:

  `http://ollama-service.llm-serving.svc.cluster.local:11434`

- **Dynamic IP Assignment**: Pod IPs and Service ClusterIPs are dynamic. Hardcoding IP addresses would make the application fragile whenever pods are rescheduled or services are recreated.

- **Namespace-Scoped Discovery**: Kubernetes Fully Qualified Domain Names follow the standard format:

  `<service-name>.<namespace>.svc.cluster.local`

  This allows services to communicate reliably across namespaces without depending on the underlying cluster topology.

- **Decoupled Architecture**: FastAPI depends on the stable Kubernetes Service abstraction rather than individual Ollama pods. This allows the Ollama backend to scale horizontally without requiring application-level configuration changes.

- **Service Abstraction**: Kubernetes Services provide a stable network endpoint and load-balancing layer in front of potentially multiple Ollama replicas.

### Service Communication Flow

```text
                    Kubernetes Cluster
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ┌──────────────────┐                                       │
│  │   FastAPI Pod    │                                       │
│  │                  │                                       │
│  │  API / Inference │                                       │
│  └────────┬─────────┘                                       │
│           │                                                 │
│           │ Kubernetes DNS                                  │
│           │ ollama-service.llm-serving.svc.cluster.local    │
│           ▼                                                 │
│  ┌──────────────────┐                                       │
│  │ Ollama Service   │                                       │
│  │                  │                                       │
│  │ ClusterIP:11434  │                                       │
│  └────────┬─────────┘                                       │
│           │                                                 │
│           ▼                                                 │
│  ┌──────────────────┐                                       │
│  │   Ollama Pod     │                                       │
│  │                  │                                       │
│  │ qwen2.5:0.5b     │                                       │
│  └──────────────────┘                                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Day 4: Automated CI/CD Pipeline & Container Registry Integration

### Accomplished

- [x] Automated CI/CD workflow created using GitHub Actions (`.github/workflows/ci.yaml`)
- [x] Code quality and linting automated using `ruff`
- [x] Automated unit test suite implemented using `pytest`
- [x] Pydantic schema validation verified
- [x] `/health` probe logic verified
- [x] Container image builds automated
- [x] Container images published to GitHub Container Registry (GHCR)
- [x] Immutable image tagging strategy implemented using Git commit SHAs (`${{ github.sha }}`)

### Architectural Rationale & Design Patterns

- **Static Code Analysis (`ruff`)**: Integrated high-performance Python linting into the CI pipeline to enforce code-quality standards and maintain consistent import ordering before container image assembly.

- **Automated Verification (`pytest`)**: Unit tests execute automatically on every push and pull request targeting `main`. This provides an early validation layer for API behavior, Pydantic schemas, and health-check endpoints before artifacts are built.

- **Immutable Artifact Strategy**: Container images are tagged using the Git commit SHA (`${{ github.sha }}`), creating a deterministic relationship between source code and the resulting artifact. This avoids the ambiguity associated with mutable tags such as `:latest`.

- **GitHub Container Registry (GHCR)**: GHCR is used as the centralized container artifact registry, providing a persistent location for versioned images that can later be consumed by Kubernetes or a GitOps deployment controller.

- **Deliberate Deployment Boundary**: The CI pipeline intentionally terminates after publishing the container image. Automated deployment to the local `kind` cluster is excluded because GitHub-hosted runners cannot directly access the developer's local Kubernetes network namespace without additional tunneling or self-hosted infrastructure.

- **GitOps Readiness**: Stopping at artifact publication establishes a clean separation between **CI** and **CD**. The resulting immutable image can later become the deployment input for a remote Kubernetes cluster and GitOps controller.

### CI/CD Pipeline Flow

```text
                         Git Repository
                              │
                              │ Push / Pull Request
                              ▼
                    ┌─────────────────────┐
                    │    GitHub Actions   │
                    │      CI Runner      │
                    └──────────┬──────────┘
                               │
                  ┌────────────┼────────────┐
                  │            │            │
                  ▼            ▼            ▼
             ┌────────┐   ┌────────┐   ┌─────────────┐
             │  Ruff  │   │ Pytest │   │ Pydantic /  │
             │ Linting│   │  Tests │   │ Health Check│
             └────┬───┘   └────┬───┘   └──────┬──────┘
                  │            │              │
                  └────────────┼──────────────┘
                               │
                         Validation Pass
                               │
                               ▼
                    ┌─────────────────────┐
                    │  Docker Image Build │
                    └──────────┬──────────┘
                               │
                               │ Tag:
                               │ <github-sha>
                               ▼
                    ┌─────────────────────┐
                    │        GHCR         │
                    │ GitHub Container    │
                    │      Registry       │
                    └──────────┬──────────┘
                               │
                               │ Immutable Artifact
                               ▼
                    ┌─────────────────────┐
                    │   Future CD /       │
                    │   GitOps Layer      │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Remote Kubernetes   │
                    │      Cluster        │
                    └─────────────────────┘

                    ─────────────────────
                     CURRENT DAY 4 STOP
                    ─────────────────────
```

### Artifact Versioning Strategy

```text
Git Commit
   │
   │ abc1234...
   ▼
GitHub Actions
   │
   │ Docker Build
   ▼
GHCR Image
   │
   └── <image>:abc1234...

Source Code ───────────────► Container Image
     │                              │
     │                              │
     └──── Git SHA ─────────────────┘
              │
              ▼
        Full Traceability
```

### Key CI/CD Pattern

```text
Code
 │
 ▼
Lint
 │
 ▼
Test
 │
 ▼
Build
 │
 ▼
Tag with Git SHA
 │
 ▼
Push to GHCR
 │
 ▼
Future GitOps Deployment
```

---
---

## Day 5: Observability Stack — Prometheus, Grafana & Golden Signals Dashboard

### Accomplished
- [x] FastAPI application instrumented using `prometheus-fastapi-instrumentator`
- [x] `/metrics` endpoint exposed on the API service
- [x] `kube-prometheus-stack` deployed via Helm into a dedicated `monitoring` namespace
- [x] `ServiceMonitor` (`llm-api-servicemonitor`) configured to scrape the API service
- [x] Prometheus target verified as `UP` with successful scrape health
- [x] Grafana dashboard built with three golden-signal panels:
  - Request rate
  - P95 latency
  - Error rate
- [x] Dashboard exported as JSON and version-controlled (`monitoring/dashboards/golden-signals.json`)
- [x] Load-tested end-to-end pipeline to validate live metric flow

### Dashboard Preview

![Golden Signals Dashboard](monitoring/dashboards/golden_signals.png)

### Architectural Rationale & Design Patterns
- **`kube-prometheus-stack` over hand-rolled manifests**: Used the community Helm chart (Prometheus + Grafana + Alertmanager bundled) rather than deploying each component manually. This mirrors how most real infrastructure teams operate this stack and avoids reinventing scrape-config plumbing.
- **ServiceMonitor as the scrape-config abstraction**: Rather than editing Prometheus's scrape config directly, a `ServiceMonitor` CRD declares *what* to scrape declaratively, and the Prometheus Operator reconciles it. This is the standard Kubernetes-native pattern for metrics discovery.
- **Golden Signals over exhaustive metrics**: The dashboard intentionally limits scope to request rate, latency (p95), and error rate — the three signals most directly tied to service health — rather than dumping every available metric onto one panel. Readability over completeness.
- **Immutable image tagging paid off**: The Day 4 SHA-based tagging strategy made it trivial to distinguish "old code, still running" from "new code, not yet deployed" once the stale-image bug surfaced (see below).

### Debugging Log

This was the real work of the day. Every fix below was a genuine dead-end resolved by checking one layer deeper — documented here because tracing failures across a distributed system is a stronger signal of competency than a dashboard screenshot alone.

**1. Prometheus silently ignoring the ServiceMonitor (label selector mismatch)**
- Symptom: `ServiceMonitor` existed, but Prometheus's Service Discovery page showed nothing.
- Root cause: `kube-prometheus-stack`'s Prometheus CR only watches `ServiceMonitors` carrying a `release: prometheus-stack` label by default (`spec.serviceMonitorSelector.matchLabels`). The custom `ServiceMonitor` didn't have it, so it was invisible to Prometheus — no error, just silence.
- Fix: added `labels: { release: prometheus-stack }` to the `ServiceMonitor`'s metadata and re-applied.

**2. ServiceMonitor discovered, but "0/0 No targets"**
- Symptom: label fix resolved discovery, but the scrape pool showed zero targets.
- Root cause: the underlying `Service` (`llm-api-service`) had no live endpoints — meaning zero pods were actually running.
- Investigation: `kubectl get deployments -n llm-serving` showed both deployments at `0/0` desired replicas, with `kubectl get events` returning nothing (no crash, no OOM, no scheduling failure — replicas had simply been set to zero, without any recorded event trail).
- Fix: `kubectl scale deployment <name> -n llm-serving --replicas=1` for both deployments.

**3. Target `UP` in discovery, but scraping failed with `404 Not Found`**
- Symptom: pod resolved correctly, Prometheus reached it over the network, but `/metrics` returned 404.
- Root cause: the running pod was serving a stale image built on Day 3, before Prometheus instrumentation was added to `main.py` on Day 5. The code was correct — it had simply never been rebuilt and reloaded into the `kind` cluster.
- Fix: `docker build` → `kind load docker-image` → bumped the image tag in the Deployment manifest → `kubectl apply` → confirmed `/metrics` returned valid Prometheus-format output before re-checking Prometheus.

**4. Port drift between local YAML, live cluster state, and the container**
- Symptom: `kubectl port-forward` failed with "Service does not have a service port 8001."
- Root cause: `api-service.yaml` had been locally edited to `port: 8001` but never re-applied, while the Dockerfile and the live cluster Service were still on `8000` — three sources of truth had drifted out of sync with each other.
- Fix: reverted the Service manifest to `8000` (matching the Dockerfile's `EXPOSE`/`uvicorn --port`), re-applied, and confirmed live cluster state matched the file before proceeding.

**Takeaway:** every failure here traced back to a *silent* mismatch — a missing label, a stale image, a config file that was edited but never applied — none of which threw a loud error until the very last layer (`/targets` page, `curl`, or `port-forward`). This is the actual shape of Kubernetes/Prometheus debugging in production: work backward through the selector chain (Prometheus → ServiceMonitor → Service → Pod) one link at a time rather than guessing at the whole system.

### Observability Data Flow
```text
                    Kubernetes Cluster
┌───────────────────────────────────────────────────────────────┐
│                                                                 │
│  ┌──────────────────┐        /metrics        ┌───────────────┐│
│  │   FastAPI Pod    │◄───────────────────────│  Prometheus   ││
│  │  (instrumented)  │      scrape every 5s    │    Server     ││
│  └──────────────────┘                         └───────┬───────┘│
│                                                        │        │
│                                            ServiceMonitor       │
│                                          (release label match)  │
│                                                        │        │
│                                                        ▼        │
│                                              ┌───────────────┐  │
│                                              │    Grafana    │  │
│                                              │   Dashboard   │  │
│                                              │ (Golden Signals)│ │
│                                              └───────────────┘  │
│                                                                 │
└───────────────────────────────────────────────────────────────┘
```

### Golden Signals Queries
```promql
# Request Rate
sum(rate(http_requests_total{job="llm-api-service"}[1m]))

# P95 Latency
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="llm-api-service"}[1m])) by (le))

# Error Rate
sum(rate(http_requests_total{job="llm-api-service", status=~"4..|5.."}[1m])) or vector(0)
```

---