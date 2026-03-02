.PHONY: all test lint clean build-docker run-docs

all: test

test:
	@echo "Lancement des tests..."
	@cd tests && bash run_tests.sh
	@cd tests && bash run_tests_core.sh
	@cd tests && bash run_tests_pipeline.sh

lint:
	@shellcheck src/integrity.sh src/lib/core.sh src/lib/ui.sh \
	            src/lib/report.sh src/lib/results.sh \
	            runner.sh docker/entrypoint.sh \
	            tests/run_tests.sh tests/run_tests_core.sh tests/run_tests_pipeline.sh

clean:
	@rm -rf ./site/
	@rm -rf /tmp/integrity-test* /tmp/integrity-core-test* /tmp/integrity-pipeline-test*

build-docker:
	@docker build -t hash_tool .

run-docs:
	@mkdocs serve