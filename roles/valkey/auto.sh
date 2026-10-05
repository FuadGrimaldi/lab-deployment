#!/bin/bash
# 1. Lint & syntax
yamllint -c .yamllint .
ansible-lint --nocolor
ansible-playbook playbooks/prep.yml --syntax-check
ansible-playbook playbooks/deploy.yml --syntax-check
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook tests/vars_check.yml --syntax-check
ansible-playbook tests/mock_prep.yml --syntax-check
ansible-playbook tests/test.yml --syntax-check

# 2. Variable validation
ansible-playbook tests/vars_check.yml

# 3. Mock prep (offline, no downloads)
ansible-playbook tests/mock_prep.yml

# 4. Molecule integration (requires Docker)
molecule test
