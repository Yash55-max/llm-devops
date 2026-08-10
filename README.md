# LLM Infrastructure & MLOps Platform

End-to-end Kubernetes-based deployment platform for serving Open-Source LLMs with automated CI/CD, IaC, and Observability.

## Day 1 Baseline Accomplished
- [x] AWS Billing Guardrails (10 alert caps configured)
- [x] AWS CLI v2 configured with non-root IAM Admin (`yash-IAM-Admin`)
- [x] Local toolchain verified (Docker v29, kubectl v1.36, kind v0.22, Terraform v1.15)
- [x] Local 2-Node K8s Cluster running via `kind` (`devops-ai-cluster`)
- [x] Ollama local model serving ready

## Day 2: Containerized Ollama Deployment into `kind`

### Architectural Rationale & Design Patterns
* **CPU-based Serving**: Retained Ollama GGUF quantized models on CPU to avoid GPU overhead and cost in local `kind` clusters.
* **Persistent Storage (`ollama-pvc`)**: Mounted a 5Gi PVC to `/root/.ollama` to decouple model weight storage from pod lifecycles, eliminating re-downloads on pod restarts.
* **Init Container Bootstrap Pattern**: Leveraged an `initContainer` (`model-puller`) to check for readiness using `ollama list` and fetch `qwen2.5:0.5b` model weights onto disk before the primary serving container starts up.

## Architectural Decisions & Service Discovery

### Kubernetes DNS vs. Hardcoded IP Addressing
In Day 3, the FastAPI layer communicates with the Ollama backend via CoreDNS domain naming:
`http://ollama-service.llm-serving.svc.cluster.local:11434`

#### Why Domain Name Discovery?
1. **Dynamic IP Assignment**: Pod IPs and Service ClusterIPs are ephemeral. Hardcoding IPs breaks whenever pods are rescheduled or services are recreated.
2. **Kubernetes Namespace Scoping**: Fully Qualified Domain Names (FQDNs) follow the standard format:
   `<service-name>.<namespace>.svc.cluster.local`
   This decoupling ensures microservices can interact reliably regardless of cluster topology or pod lifecycle events.
3. **Decoupled Architecture**: Allows scaling the backend (e.g., adding multiple Ollama instances behind a load balancer) without modifying application configurations.
