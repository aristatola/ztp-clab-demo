CURRENT_DIR := $(shell pwd)
DEV ?= ztp-switch1
ZTP_SWITCHES := ztp-switch1 ztp-switch2 ztp-switch3

.PHONY: help
help: ## Display help message
	@grep -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: generate
generate: ## Generate lab files from demo-config.yaml
	@echo "Generating lab files from demo-config.yaml..."
	@python3 $(CURRENT_DIR)/scripts/generate.py

.PHONY: start
start: generate ## Deploy lab (generates configs first)
	sudo containerlab deploy --debug --topo $(CURRENT_DIR)/clab/topology.clab.yml --max-workers 10 --timeout 5m --reconfigure

.PHONY: stop
stop: ## Destroy lab
	sudo containerlab destroy --debug --topo $(CURRENT_DIR)/clab/topology.clab.yml --cleanup

.PHONY: inspect
inspect: ## Show lab node IPs and status
	@sudo containerlab inspect --topo $(CURRENT_DIR)/clab/topology.clab.yml
	@echo ""
	@echo "Credentials: admin/admin or arista/arista"
	@echo "Console:     make console DEV=<node>"
	@echo "Logs:        make logs DEV=<node>"

.PHONY: ztp-start
ztp-start: ## Enable web server on mgmt-sw01 (starts ZTP)
	@echo "Enabling web server on mgmt-sw01..."
	@docker exec mgmt-sw01 Cli -p 15 -c "web on"
	@echo "Web server enabled. ZTP switches will begin bootstrapping."

.PHONY: ztp-stop
ztp-stop: ## Disable web server on mgmt-sw01 (stops ZTP)
	@echo "Disabling web server on mgmt-sw01..."
	@docker exec mgmt-sw01 Cli -p 15 -c "web off"
	@echo "Web server disabled."

.PHONY: ztp-reset
ztp-reset: ## Reset to ZTP mode (all ZTP switches, or DEV=<node> for one)
ifeq ($(origin DEV),command line)
	@echo "Resetting $(DEV) to ZTP mode..."
	-@docker exec $(DEV) Cli -p 15 -c "run delete flash:startup-config; bash sudo service ProcMgr restart"
	@echo "$(DEV) reset complete."
else
	@echo "Resetting all ZTP switches to ZTP mode..."
	@for sw in $(ZTP_SWITCHES); do \
		echo "  Resetting $$sw..."; \
		docker exec $$sw Cli -p 15 -c "run delete flash:startup-config; bash sudo service ProcMgr restart" || true; \
	done
	@echo "All ZTP switches reset."
endif

.PHONY: console
console: ## Open EOS CLI on a device (DEV=<node>, default: ztp-switch1)
	docker exec -it $(DEV) Cli

.PHONY: logs
logs: ## Follow container logs (DEV=<node>, default: ztp-switch1)
	docker logs $(DEV) -f
