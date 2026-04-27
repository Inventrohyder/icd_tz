WORKSPACE ?= $(CURDIR)
DEVCONTAINER ?= devcontainer
APP_URL ?= http://127.0.0.1:8000/app/icd
SITE ?= icdtz.localhost
BENCH_ROOT ?= /workspace/development
BENCH_NAME ?= frappe-bench
BENCH_DIR ?= $(BENCH_ROOT)/$(BENCH_NAME)

.PHONY: help dev-up dev-setup dev-start dev-stop dev-shell dev-status bench-setup bench-start bench-stop bench-status

help:
	@printf '%s\n' \
		'ICD-TZ developer commands:' \
		'' \
		'Host terminal:' \
		'  make dev-up      Build/start the Dev Container and run setup' \
		'  make dev-start   Start Frappe Bench through the Dev Container' \
		'  make dev-stop    Stop Frappe Bench through the Dev Container' \
		'  make dev-status  Show installed Frappe apps through the Dev Container' \
		'  make dev-setup   Re-run setup through the Dev Container' \
		'  make dev-shell   Open a shell inside the Dev Container' \
		'' \
		'Inside the Dev Container:' \
		'  make bench-setup   Re-run the Bench setup script' \
		'  make bench-start   Start Frappe Bench in the foreground' \
		'  make bench-stop    Stop the running Frappe Bench process' \
		'  make bench-status  Show installed Frappe apps' \
		'' \
		'Open: $(APP_URL)'

dev-up:
	$(DEVCONTAINER) up --workspace-folder "$(WORKSPACE)"

dev-setup:
	$(DEVCONTAINER) exec --workspace-folder "$(WORKSPACE)" bash -lc 'make bench-setup'

dev-start:
	$(DEVCONTAINER) exec --workspace-folder "$(WORKSPACE)" bash -lc 'make bench-start'

dev-stop:
	$(DEVCONTAINER) exec --workspace-folder "$(WORKSPACE)" bash -lc 'make bench-stop'

dev-shell:
	$(DEVCONTAINER) exec --workspace-folder "$(WORKSPACE)" bash

dev-status:
	$(DEVCONTAINER) exec --workspace-folder "$(WORKSPACE)" bash -lc 'make bench-status'

bench-setup:
	bash .devcontainer/setup-icd-tz.sh

bench-start:
	bash .devcontainer/start-icd-tz.sh

bench-stop:
	bash .devcontainer/stop-icd-tz.sh

bench-status:
	cd "$(BENCH_DIR)" && bench --site "$(SITE)" list-apps
