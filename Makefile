.PHONY: virtualenv
virtualenv: ## create virtual environment typically used for development purposes
	virtualenv env --setuptools --prompt='(benchmark_automation)'

.PHONY: rebuild-requirements
rebuild-requirements: ## Rebuild requirements files requirements.txt and requirements_dev.txt
	pip-compile --verbose --no-index --output-file requirements.txt requirements.in
	pip-compile --verbose --no-index --output-file requirements_dev.txt requirements_dev.in

.PHONY: upgrade-requirements
upgrade-requirements: ## Upgrade requirements
	pip-compile --upgrade --verbose --no-index --output-file requirements.txt requirements.in
	pip-compile --upgrade --verbose --no-index --output-file requirements_dev.txt requirements_dev.in

.PHONY: bootstrap
bootstrap: ## bootstrap the development environment
	pip install -U "setuptools==32.3.1"
	pip install -U "pip==9.0.1"
	pip install -U "pip-tools>=1.6.0"
	pip-sync requirements.txt requirements_dev.txt

.PHONY: clean
clean: clean-build clean-pyc clean-test ## remove all build, test, coverage and Python artifacts

.PHONY: clean-build
clean-build: ## remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

.PHONY: clean-pyc
clean-pyc: ## remove Python file artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

.PHONY: clean-test
clean-test: ## remove test and coverage artifacts
	rm -fr .tox/
	rm -f .coverage
	rm -fr htmlcov/

.PHONY: flake8
flake8:
	flake8 --exclude=env/
