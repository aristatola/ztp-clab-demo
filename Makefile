CURRENT_DIR := $(shell pwd)
DEV ?= ztp-switch1

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
<<<<<<< HEAD
	@echo "You can check the lab status, hostnames and management addresses above."
	@echo "To connect to a lab device use \`ssh admin@<hostname>\` and password \`admin\`."

.PHONY: ssh-sw1
ssh-sw1: ## Connect to switch1
	docker exec -it ztp-switch1 Cli

.PHONY: ssh-sw2
ssh-sw2: ## Connect to switch2
	docker exec -it ztp-switch2 Cli

.PHONY: ssh-sw3
ssh-sw3: ## Connect to switch3
	docker exec -it ztp-switch3 Cli

.PHONY: watch-sw1
watch-sw1: ## Destroy ceos lab
	docker logs ztp-switch1 -f

.PHONY: watch-sw2
watch-sw2: ## Destroy ceos lab
	docker logs ztp-switch2 -f

.PHONY: watch-sw3
watch-sw3: ## Destroy ceos lab
	docker logs ztp-switch3 -f
=======
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

.PHONY: console
console: ## Open EOS CLI on a device (DEV=<node>, default: ztp-switch1)
	docker exec -it $(DEV) Cli

.PHONY: logs
logs: ## Follow container logs (DEV=<node>, default: ztp-switch1)
	docker logs $(DEV) -f
>>>>>>> 16861f9 (Adding configuration capabilities)
