.PHONY: validate package ci release

validate:
	bash scripts/validate

package: validate
	bash scripts/package

ci:
	bash scripts/ci

release:
	bash scripts/release

.DEFAULT_GOAL := ci
