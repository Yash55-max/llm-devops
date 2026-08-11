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