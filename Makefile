NODE ?= $(shell if [ -x "$(HOME)/.nvm/versions/node/v22.22.2/bin/node" ]; then printf '%s' "$(HOME)/.nvm/versions/node/v22.22.2/bin/node"; else command -v node; fi)
OPENCLAW ?= ./openclaw.mjs
STATE_DIR ?= .local
GATEWAY_PID ?= $(STATE_DIR)/openclaw-gateway.pid
GATEWAY_LOG ?= $(STATE_DIR)/openclaw-gateway.log

.PHONY: build install start stop

build:
	pnpm build

install:
	pnpm install

start:
	pnpm ui:build
	@if [ -z "$(NODE)" ]; then echo "Node.js not found. Install Node 22+ or run make NODE=/path/to/node start." >&2; exit 1; fi
	@mkdir -p "$(STATE_DIR)"
	@if [ -f "$(GATEWAY_PID)" ] && kill -0 "$$(cat "$(GATEWAY_PID)")" >/dev/null 2>&1; then \
		echo "OpenClaw gateway already running with pid $$(cat "$(GATEWAY_PID)")."; \
	else \
		echo "Starting OpenClaw gateway..."; \
		nohup "$(NODE)" "$(OPENCLAW)" gateway run --force >"$(GATEWAY_LOG)" 2>&1 & \
		echo $$! >"$(GATEWAY_PID)"; \
		sleep 2; \
		if ! kill -0 "$$(cat "$(GATEWAY_PID)")" >/dev/null 2>&1; then \
			echo "OpenClaw gateway failed to start. Last log lines:" >&2; \
			tail -n 80 "$(GATEWAY_LOG)" >&2; \
			exit 1; \
		fi; \
		echo "OpenClaw gateway running with pid $$(cat "$(GATEWAY_PID)"). Logs: $(GATEWAY_LOG)"; \
	fi
	@"$(NODE)" "$(OPENCLAW)" dashboard

stop:
	@if [ -n "$(NODE)" ]; then "$(NODE)" "$(OPENCLAW)" gateway stop >/dev/null 2>&1 || true; fi
	@if [ -f "$(GATEWAY_PID)" ] && kill -0 "$$(cat "$(GATEWAY_PID)")" >/dev/null 2>&1; then \
		echo "Stopping OpenClaw gateway pid $$(cat "$(GATEWAY_PID)")..."; \
		kill "$$(cat "$(GATEWAY_PID)")"; \
		rm -f "$(GATEWAY_PID)"; \
	else \
		echo "No tracked OpenClaw gateway process is running."; \
		rm -f "$(GATEWAY_PID)"; \
	fi
