# Echo API — Cloud-Native Deployment with Kubernetes & CI/CD

This repository contains a production-style deployment of a Node.js Express application,
built as part of the "Software Engineering in Practice" course assignment.
The goal is not just to run an app, but to containerize it with Docker, automatically build it and publish it via GitHub Actions,
and orchestrate it inside a local Kubernetes cluster (Minikube), following the
12-Factor App principles for configuration and secret management.

## Table of Contents
* Prerequisites
* Repository Structure
* Step 1 : Clone the Repository
* Step 2 : Start Minikube
* Step 3 : Apply the Kubernetes Manifests
* Step 4 : Verify the Deployment
* Step 5 : Interact with the Endpoints
* CI/CD Pipeline

## Prerequisites
Before you begin, ensure you have the following tools installed and configured on your local machine:
* **Git**, to clone the repository
* **Docker**, to build and run container images
* **Minikube**, to run a local Kubernetes
* **kubectl**, to send commands to Kubernetes

## Repository Structure
```
seip_assignment_1_2026/
│
├── server.js                  # Main application file, do not modify
├── package.json               # App dependencies
├── Dockerfile                 # Instructions to build the production container image
│
├── .github/
│   └── workflows/
│       └── ci-cd.yaml         # GitHub Actions pipeline: Build & Push Docker Image to GHCR
│
└── k8s/                       # All Kubernetes manifests live here
    ├── configmap.yaml         # Non-sensitive config (WELCOME_MESSAGE, NODE_ENV)
    ├── secret.yaml            # Sensitive credentials and passwords (API_SECRET_KEY encoded in Base64)
    ├── deployment.yaml        # Workload definition: 3 replicas, resource limits, health probes
    └── service.yaml           # Internal networking: ClusterIP, map port 80 & 3000
The k8s/ directory is intentionally self-contained, as every resource the app needs
to run is declared there, and the entire infrastructure can be applied with a single command.
```

## Step 1 : Clone the Repository
``` bash 
git clone https://github.com/DESPOINALAMPROU/seip_assignment_1_2026.git
cd seip_assignment_1_2026 
```

## Step 2 : Start Minikube
Start your local Kubernetes cluster:
``` bash
minikube start
```
Confirm the node is up and ready:
``` bash
kubectl get nodes
```
Expected output: 
| NAME     | STATUS | ROLES         | AGE | VERSION|
| :------- | :----- | :-------------| :-- | :------|
| minikube | Ready  | control-plane | ... | v1.x.x |

The cluster is ready once the status shows "Ready".

## Step 3 : Apply the Kubernetes Manifests
All manifests are applied at once using a single command that reads
every file inside the k8s/ directory:
``` bash
kubectl apply -f k8s/
```
Kubernetes will process them in alphabetical order:
1. configmap.yaml — creates the environment (non-sensitive data) variables that the app needs at runtime
2. deployment.yaml — creates 3 identical pods (copies) running the container image
3. secret.yaml — securely injects the API key (sensitive data) into the pods
4. service.yaml — sets up internal networking so the pods are reachable and able to receive traffic

This is the 12-Factor approach enforced: the application code never holds
configuration or secrets inside, on the contrary they are injected from the outside at boot time.

## Step 4 : Verify the Deployment
Wait for all 3 pods to reach "Running" status:
``` bash 
kubectl get pods
```
| NAME | READY | STATUS | RESTARTS | AGE |
|------|-------|--------|----------|-----|
| echo-api-deployment-xxxxxxxxx-xxxxx | 1/1 | Running | 0 | 30s |
| echo-api-deployment-xxxxxxxxx-xxxxx | 1/1 | Running | 0 | 30s |
| echo-api-deployment-xxxxxxxxx-xxxxx | 1/1 | Running | 0 | 30s |

All 3 pods must show 1/1 under READY before proceeding.
Kubernetes keeps exactly 3 replicas running at all times — if one crashes,
it is automatically restarted. This is the self-healing behavior enforced by the Deployment

Check that the Service was created:
``` bash
kubectl get services
```
To inspect the full deployment details (resource limits, probe configuration, injected env vars):
``` bash
kubectl describe deployment echo-api-deployment
```

## Step 5 : Interact with the Endpoints 
The Service is of type ClusterIP, which means it is only reachable
from inside the cluster — this is intentional for internal workloads.
To access it from your local machine during development, use kubectl port-forward:

``` bash 
kubectl port-forward service/echo-api-service 8080:80
```
Keep this terminal open. Open a new terminal and use the commands below.

### GET / — Main endpoint
Returns the WELCOME_MESSAGE and NODE_ENV values injected from the ConfigMap.
This confirms that non-sensitive configuration is wired correctly.
```bash 
curl http://localhost:8080/
```
Expected response:
```json
{
  "message": "Welcome to the Software Engineering in Practice Assignment Cluster!",
  "environment": "production"
}
```
### GET /secure-config — Secret validation endpoint
Confirms that the API_SECRET_KEY was injected correctly from the Kubernetes Secret.
The app masks all but the last 4 characters of the key — proving the secret
was received without ever exposing it in full.
``` bash 
curl http://localhost:8080/secure-config
```
Expected Response: 
```json
{
  "status": "Authorized",
  "injected_secret_suffix": "****xxxx"
}
```
If you see a "Security breach" error instead, the Secret was not injected correctly.
Run kubectl describe pod <pod-name> to inspect the environment variables on the pod.
### GET /health — Health check endpoint
Used internally by Kubernetes for the livenessProbe and readinessProbe
defined in deployment.yaml. Kubernetes hits this endpoint automatically
every few seconds to decide whether a pod is alive and ready to receive traffic.
``` bash 
curl http://localhost:8080/health
```
Expected response:
```json 
{
  "status": "Healthy"
}
```

---

## CI/CD Pipeline 
Every push to the main branch automatically triggers the GitHub Actions workflow
defined in .github/workflows/ci-cd.yaml.
The pipeline runs on a GitHub-hosted Ubuntu runner and executes these steps:
1. Checkout — pulls the latest code from the repository
2. Login — authenticates to the GitHub Container Registry (GHCR) using the built-in GITHUB_TOKEN — no manual secrets needed
3. Build — builds the Docker image using the Dockerfile at the root of the repo
4. Push — publishes the image to ghcr.io/DESPOINALAMPROU/echo-api:latest
You can monitor each run live under the Actions tab of the repository.
The image published by the pipeline is the same image referenced in deployment.yaml,
which is what closes the loop between writing code and running it in Kubernetes.