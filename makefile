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
LAYERS_DIR     = ./infra
LAYER       ?=
LAYER_PATH  = $(LAYERS_DIR)/$(LAYER)
MOD_DIR    = ./modules
STATE_FILE = terraform.tfplan
# init plan apply and destroy all
ENV = prod
LAYERS_ALL = network security iam data compute
LAYERS_REV = compute data iam security network

# --- GUARDS ---
require-layer:
	@if [ -z "$(LAYER)" ]; then \
		echo "Error: LAYER is required. Usage: make <target> LAYER=<name>"; \
		echo "Available layers:"; \
		ls -1 $(LAYERS_DIR); \
		exit 1; \
	fi
	@if [ ! -d "$(LAYER_PATH)" ]; then \
		echo "Error: layer '$(LAYER)' not found in $(LAYERS_DIR)/"; \
		echo "Available layers:"; \
		ls -1 $(LAYERS_DIR); \
		exit 1; \
	fi

# --- HELPERS ---
define AWS_IDENTITY
	@echo "-----------------------"
	@echo "Current AWS Identity:"
	@AWS_PAGER="" aws sts get-caller-identity --query "Arn" --output text
	@echo "-----------------------"
endef

define TFPLAN_SUMMARY
	@chmod u+x scripts/tfplan_summary.sh
	@./scripts/tfplan_summary.sh $(LAYER_PATH)/$(STATE_FILE)
	@chmod u-x scripts/tfplan_summary.sh
endef

.PHONY: all verify-identity init plan apply destroy state-rm \
        resources show state output init-all plan-all apply-all destroy-all\
		format validate check prec prec-all help

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

init: require-layer ## Initialize a layer - make init LAYER=layer-name
	$(AWS_IDENTITY)
	@echo "Initializing $(LAYER)..."
	@cd $(LAYER_PATH) && terraform init -backend-config=../backend.hcl -reconfigure

plan: require-layer ## Plan a layer - make plan LAYER=layer-name
	$(AWS_IDENTITY)
	@echo "Generating plan $(LAYER)..."
	@cd $(LAYER_PATH) && terraform plan -var-file=../global.tfvars -var-file=terraform.tfvars -out=$(STATE_FILE)
	$(TFPLAN_SUMMARY)

apply: require-layer ## Apply a layer - make apply LAYER=layer-name
	$(AWS_IDENTITY)
	@echo "Applying changes $(LAYER)..."
	@cd $(LAYER_PATH) && terraform apply $(STATE_FILE)

destroy: require-layer ## Destroy a layer - make destroy LAYER=layer-name
	$(AWS_IDENTITY)
	@echo "WARNING: Destroying infrastructure of $(LAYER)."
	@cd $(LAYER_PATH) && terraform destroy -var-file=../global.tfvars -var-file=terraform.tfvars

state-rm: require-layer ## Remove a resource from state - make state-rm LAYER=layer-name RES='resource.address'
	$(AWS_IDENTITY)
	@cd $(LAYER_PATH) && terraform state rm '$(RES)'

import: require-layer # Usage: make import LAYER=network RES=aws_vpc.this ID=vpc-0abc123
	@cd $(LAYER_PATH) && terraform import \
		-var-file=../global.tfvars \
		-var-file=terraform.tfvars \
		$(RES) $(ID)

resources: require-layer ## List resources - make resources LAYER=layer-name
	$(AWS_IDENTITY)
	@cd $(LAYER_PATH) && terraform state list

show: require-layer ## Show a resource - make show LAYER=layer-name RES='resource.adress'
	$(AWS_IDENTITY)
	@cd $(LAYER_PATH) && terraform state show $(RES)

state: require-layer ## Pull state - make state LAYER=layer-name
	$(AWS_IDENTITY)
	@cd $(LAYER_PATH) && terraform state pull

output: require-layer ## Show outputs - make output LAYER=layer-name
	$(AWS_IDENTITY)
	@cd $(LAYER_PATH) && terraform output -json | jq '.'

# =============================================================================
# ALL UNITS COMMANDS - uses terraform run-all
# =============================================================================
init-all: ## Init all layers
	@for layer in $(LAYERS_ALL); do \
		echo "=== Init $$layer ==="; \
		cd $(LAYERS_DIR)/$$layer && terraform init \
			-backend-config=../backend.hcl \
		&& cd $(CURDIR); \
	done

plan-all: ## Plan all layers in order
	@for layer in $(LAYERS_ALL); do \
		echo "=== Planning $$layer ==="; \
		cd $(LAYERS_DIR)/$$layer && terraform plan -var-file=../global.tfvars -var-file=terraform.tfvars \
		&& cd $(CURDIR); \
	done

apply-all: ## Apply all layers in order
	@for layer in $(LAYERS_ALL); do \
		echo "=== Applying $$layer ==="; \
		cd $(LAYERS_DIR)/$$layer && terraform apply -var-file=../global.tfvars -var-file=terraform.tfvars -auto-approve && cd $(CURDIR); \
	done

destroy-all: ## Destroy all layers in reverse order
	@for layer in $(LAYERS_REV); do \
		echo "=== Destroying $$layer ==="; \
		cd $(LAYERS_DIR)/$$layer && terraform destroy -var-file=../global.tfvars -var-file=terraform.tfvars -auto-approve && cd $(CURDIR); \
	done

# =============================================================================
# QUALITY AND SECURITY
# =============================================================================

format: ## Format - make format LAYER=layer-name
	@echo "Formatting code..."
	@terraform fmt -recursive $(LAYERS_DIR)
	@if [ -d $(MOD_DIR) ]; then terraform fmt -recursive $(MOD_DIR); fi

validate: require-layer ## Validate - make validate LAYER=layer-name
	$(AWS_IDENTITY)
	@echo "Validating code..."
	@cd $(LAYERS_PATH) && terraform validate

check: ## Security scan infra and modules
	@echo "-----------------------"
	@echo "Running TFLint..."
	@tflint --chdir=$(LAYERS_DIR) --config=$(CURDIR)/.tflint.hcl
	@if [ -d $(MOD_DIR) ]; then tflint --chdir=$(MOD_DIR) --recursive --config=$(CURDIR)/.tflint.hcl; fi
	@echo "-----------------------"
	@echo "Scanning for vulnerabilities..."
	@trivy config --severity MEDIUM,HIGH,CRITICAL $(LAYERS_DIR)
	@if [ -d $(MOD_DIR) ]; then trivy config --severity MEDIUM,HIGH,CRITICAL $(MOD_DIR); fi

lint-init: ## Install tflint plugins
	tflint --init --chdir=$(LAYERS_DIR)
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
