# =============================================================================
# MAKEFILE - single (terraform)
#
# Usage:
#   make init        -> initialize backend
#   make plan        -> plan changes
#   make apply       -> apply changes
#   make resources   -> list resources in state
# =============================================================================

# --- VARIABLES ---
TF_DIR     = ./infra
MOD_DIR    = ./modules
STATE_FILE = terraform.tfplan

# --- HELPERS ---
define AWS_IDENTITY
	@echo "-----------------------"
	@echo "Current AWS Identity:"
	@AWS_PAGER="" aws sts get-caller-identity --query "Arn" --output text
	@echo "-----------------------"
endef

define TFPLAN_SUMMARY
	@chmod u+x scripts/tfplan_summary.sh
	@./scripts/tfplan_summary.sh $(TF_DIR)/$(STATE_FILE)
	@chmod u-x scripts/tfplan_summary.sh
endef

.PHONY: all verify-identity init plan apply destroy state-rm \
        resources show state output format validate check prec prec-all help

# Default action
all: check validate plan

# =============================================================================
# AWS
# =============================================================================

verify-identity: ## Show current AWS identity
	$(AWS_IDENTITY)

# =============================================================================
# TERRAFORM COMMANDS
# =============================================================================

init: ## Initialize backend
	$(AWS_IDENTITY)
	@echo "Initializing..."
	@terraform -chdir=$(TF_DIR) init -backend-config=backend.hcl -reconfigure

plan: ## Generate execution plan
	$(AWS_IDENTITY)
	@echo "Generating plan..."
	@terraform -chdir=$(TF_DIR) plan -var-file=terraform.tfvars -out=$(STATE_FILE)
	$(TFPLAN_SUMMARY)

apply: ## Apply changes
	$(AWS_IDENTITY)
	@echo "Applying changes..."
	@terraform -chdir=$(TF_DIR) apply $(STATE_FILE)

destroy: ## Destroy infrastructure
	$(AWS_IDENTITY)
	@echo "WARNING: Destroying infrastructure."
	@terraform -chdir=$(TF_DIR) destroy -var-file=terraform.tfvars

state-rm:  ## Remove a resource from state - make state-rm RES='resource.address'
	$(AWS_IDENTITY)
	@terraform -chdir=$(TF_DIR) state rm '$(RES)'

resources: ## List all tfstate resources
	$(AWS_IDENTITY)
	@terraform -chdir=$(TF_DIR) state list

show: ## Show resource in tfstate - make show RES='aws_iam_policy.x'
	$(AWS_IDENTITY)
	@terraform -chdir=$(TF_DIR) state show $(RES)

state: ## Pull tfstate - make state
	$(AWS_IDENTITY)
	@terraform -chdir=$(TF_DIR) state pull

output: ## Show tfstate outputs
	$(AWS_IDENTITY)
	@terraform -chdir=$(TF_DIR) output -json | jq '.'

# =============================================================================
# QUALITY AND SECURITY
# =============================================================================

format: ## Format and validate Terraform code
	@echo "Formatting code..."
	@terraform fmt -recursive $(TF_DIR)
	@if [ -d $(MOD_DIR) ]; then terraform fmt -recursive $(MOD_DIR); fi

validate:
	$(AWS_IDENTITY)
	@echo "Validating code..."
	@cd $(TF_DIR) && terraform validate
	@if [ -d $(MOD_DIR) ]; then terraform -chdir=$(MOD_DIR) validate; fi

check: ## Security scan infra and modules
	@echo "-----------------------"
	@echo "Running TFLint..."
	@tflint --chdir=$(TF_DIR) --config=$(CURDIR)/.tflint.hcl
	@if [ -d $(MOD_DIR) ]; then tflint --chdir=$(MOD_DIR) --recursive --config=$(CURDIR)/.tflint.hcl; fi
	@echo "-----------------------"
	@echo "Scanning for vulnerabilities..."
	@trivy config --severity MEDIUM,HIGH,CRITICAL $(TF_DIR)
	@if [ -d $(MOD_DIR) ]; then trivy config --severity MEDIUM,HIGH,CRITICAL $(MOD_DIR); fi

lint-init: ## Install tflint plugins
	tflint --init --chdir=$(TF_DIR)
	@[ -d $(MOD_DIR) ] && tflint --init --chdir=$(MOD_DIR) || true

# =============================================================================
# PRE-COMMIT
# =============================================================================

prec: ## Run pre-commit on staged files
	@pre-commit run

prec-all: ## Run pre-commit on all files
	@pre-commit run --all-files

# =============================================================================
# UTILITIES
# =============================================================================

help: ## Show this help menu
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
