pipeline {
    agent {
        docker {
            image 'python:3.12'
            args '-v /var/run/docker.sock:/var/run/docker.sock -u root:root'
        }
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }

    environment {
        PIP_BREAK_SYSTEM_PACKAGES = '1'
    }

    stages {
        stage('Install Dependencies') {
            steps {
                sh '''                    
                    pip install ansible ansible-lint yamllint
                    apt-get update && apt-get install -y --no-install-recommends docker.io docker-cli rsync
                '''
            }
        }

        stage('Lint & Syntax Check') {
            steps {
                sh 'yamllint -c .yamllint .'
                sh 'ansible-lint --nocolor'
                sh '''
                    for f in playbooks/*.yml tests/*.yml; do
                        ansible-playbook "$f" --syntax-check
                    done
                '''
            }
        }

        stage('Variable Validation') {
            steps {
                sh 'ansible-playbook tests/vars_check.yml'
            }
        }

        stage('Mock Prep Test') {
            steps {
                sh 'ansible-playbook tests/mock_prep.yml'
            }
        }

        stage('Molecule Integration') {
            when {
                expression {                    
                    (env.GIT_BRANCH ?: '') ==~ /.*development$/ &&
                    sh(script: 'docker info > /dev/null 2>&1', returnStatus: true) == 0
                }
            }
            steps {
                sh 'pip install molecule "molecule-plugins[docker]"'
                sh 'molecule test'
                sh 'molecule cleanup'
            }
        }
    }
}

