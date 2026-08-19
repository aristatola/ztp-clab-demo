CURRENT_DIR := $(shell pwd)

.PHONY: help
help: ## Display help message
	@grep -E '^[0-9a-zA-Z_-]+\.*[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: start
start: ## Deploy ceos lab
	sudo containerlab deploy --debug --topo $(CURRENT_DIR)/clab/topology.clab.yml --max-workers 10 --timeout 5m --reconfigure

.PHONY: stop
stop: ## Destroy ceos lab
	sudo containerlab destroy --debug --topo $(CURRENT_DIR)/clab/topology.clab.yml --cleanup

.PHONY: inspect
inspect: ## Inspect ceos lab
	@sudo containerlab inspect --topo $(CURRENT_DIR)/clab/topology.clab.yml
	@echo ""
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
