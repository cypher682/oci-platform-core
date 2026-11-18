# ─────────────────────────────────────────────
# oci-platform-core Makefile
# Usage: make <target> ENV=dev|prod
# ─────────────────────────────────────────────

SHELL   := /bin/bash
ENV     ?= dev
TF_DIR  := environments/$(ENV)
REGION  ?= us-ashburn-1
KUBECONFIG_OCI ?= $(HOME)/.kube/config-oci-platform
IMAGE   ?= iad.ocir.io/NAMESPACE/platform-api:latest
REGISTRY ?= iad.ocir.io

.PHONY: help preflight init fmt validate plan apply destroy output inventory lint \
        ansible ansible-syntax kubeconfig deploy-k8s ocir-login build-push smoke evidence cost

help: ## Show available targets
	@echo ""
	@echo "oci-platform-core — targets"
	@echo "==========================="
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "ENV defaults to dev. Override: make plan ENV=prod"

preflight: ## Check required OCI credentials and local tools
	@bash scripts/preflight.sh

init: ## terraform init
	cd $(TF_DIR) && terraform init

fmt: ## terraform fmt across the repository
	terraform fmt -recursive

validate: ## terraform validate
	cd $(TF_DIR) && terraform validate

plan: preflight ## terraform plan
	cd $(TF_DIR) && terraform plan -out=tfplan

apply: preflight ## terraform apply (saved plan when available)
	cd $(TF_DIR) && terraform apply -auto-approve

destroy: ## terraform destroy — tears the environment down
	@echo "⚠  This destroys every resource in $(ENV)."
	@read -p "Type 'destroy-$(ENV)' to confirm: " confirm && [ "$$confirm" = "destroy-$(ENV)" ] || exit 1
	cd $(TF_DIR) && terraform destroy -auto-approve

output: ## Print all outputs
	cd $(TF_DIR) && terraform output

inventory: ## Render the Ansible inventory from Terraform state
	cd $(TF_DIR) && terraform output -raw ansible_inventory > ../../ansible/inventory/hosts.ini
	@echo "Wrote ansible/inventory/hosts.ini — copy it to the ops runner."

lint: ## tflint + checkov (IaC security)
	tflint --recursive || true
	checkov -d . --framework terraform --compact --quiet

ansible-syntax: ## Syntax-check the playbook
	cd ansible && ansible-playbook site.yml -i inventory/hosts.ini --syntax-check

ansible: ## Run the full playbook (execute ON the ops runner)
	cd ansible && ansible-playbook site.yml -i inventory/hosts.ini

kubeconfig: ## Write an OKE kubeconfig to $(KUBECONFIG_OCI)
	@CLUSTER_ID=$$(cd $(TF_DIR) && terraform output -raw oke_cluster_id 2>/dev/null); \
	if [ -z "$$CLUSTER_ID" ] || [ "$$CLUSTER_ID" = "null" ]; then echo "OKE is disabled in $(ENV)"; exit 1; fi; \
	oci ce cluster create-kubeconfig \
		--cluster-id "$$CLUSTER_ID" \
		--file $(KUBECONFIG_OCI) \
		--region $(REGION) \
		--token-version 2.0.0 \
		--kube-endpoint PUBLIC_ENDPOINT
	@echo "KUBECONFIG=$(KUBECONFIG_OCI)"

deploy-k8s: ## Build the OCIR pull secret and deploy the Kubernetes workload
	@test -n "$$OCIR_USERNAME" || (echo "OCIR_USERNAME is not set" && exit 1)
	@test -n "$$OCIR_AUTH_TOKEN" || (echo "OCIR_AUTH_TOKEN is not set" && exit 1)
	KUBECONFIG=$(KUBECONFIG_OCI) kubectl create namespace platform --dry-run=client -o yaml | KUBECONFIG=$(KUBECONFIG_OCI) kubectl apply -f -
	KUBECONFIG=$(KUBECONFIG_OCI) kubectl -n platform create secret docker-registry ocir-secret \
		--docker-server=$(REGISTRY) \
		--docker-username="$$OCIR_USERNAME" \
		--docker-password="$$OCIR_AUTH_TOKEN" \
		--dry-run=client -o yaml | KUBECONFIG=$(KUBECONFIG_OCI) kubectl apply -f -
	rm -rf /tmp/oci-platform-k8s
	cp -r k8s /tmp/oci-platform-k8s
	IMAGE_NAME="$${IMAGE%:*}"; IMAGE_TAG="$${IMAGE##*:}"; \
	sed -i "s|newName:.*|newName: $$IMAGE_NAME|; s|newTag:.*|newTag: $$IMAGE_TAG|" /tmp/oci-platform-k8s/kustomization.yaml
	KUBECONFIG=$(KUBECONFIG_OCI) kubectl apply -k /tmp/oci-platform-k8s
	KUBECONFIG=$(KUBECONFIG_OCI) kubectl -n platform rollout status deployment/platform-api --timeout=180s

ocir-login: ## docker login to OCIR
	@test -n "$$OCIR_USERNAME" || (echo "OCIR_USERNAME is not set" && exit 1)
	@test -n "$$OCIR_AUTH_TOKEN" || (echo "OCIR_AUTH_TOKEN is not set" && exit 1)
	docker login $(REGISTRY) -u "$$OCIR_USERNAME" -p "$$OCIR_AUTH_TOKEN"

build-push: ## Build and push the sample application
	docker build --build-arg VERSION=$$(git rev-parse --short HEAD) -t $(IMAGE) app
	docker push $(IMAGE)

smoke: ## Curl the Terraform-managed load balancer health endpoint
	@bash scripts/smoke.sh $(ENV)

evidence: ## Capture the evidence pack into docs/evidence/
	@bash scripts/evidence.sh $(ENV)

cost: ## Infracost estimate (requires infracost)
	infracost breakdown --path $(TF_DIR) --format table
