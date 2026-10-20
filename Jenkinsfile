pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    environment {
        BUILD_HOST = '10.0.1.170'
        PROD_HOST  = '10.0.1.218'
        IMAGE_NAME = 'abode-webapp'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Job 1 - Build') {
            steps {
                sshagent(credentials: ['abode-deploy-key']) {
                    sh '''
                        set -eu

                        tar --exclude=.git -czf - . | \
                          ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                          ubuntu@${BUILD_HOST} \
                          'rm -rf /home/ubuntu/abode-app &&
                           mkdir -p /home/ubuntu/abode-app &&
                           tar -xzf - -C /home/ubuntu/abode-app'

                        ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                          ubuntu@${BUILD_HOST} \
                          "sudo docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} -t ${IMAGE_NAME}:latest /home/ubuntu/abode-app"
                    '''
                }
            }
        }

        stage('Job 2 - Test') {
            steps {
                sshagent(credentials: ['abode-deploy-key']) {
                    sh '''
                        set -eu

                        ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                          ubuntu@${BUILD_HOST} \
                          "sudo docker rm -f abode-test >/dev/null 2>&1 || true; sudo docker run -d --name abode-test -p 127.0.0.1:18080:80 ${IMAGE_NAME}:${BUILD_NUMBER}"

                        passed=0
                        for attempt in $(seq 1 10); do
                            if ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                              ubuntu@${BUILD_HOST} \
                              'curl -fsS http://127.0.0.1:18080/ -o /dev/null'; then
                                passed=1
                                break
                            fi
                            sleep 2
                        done

                        if [ "$passed" -ne 1 ]; then
                            ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                              ubuntu@${BUILD_HOST} \
                              'sudo docker logs abode-test; sudo docker rm -f abode-test || true'
                            exit 1
                        fi

                        ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                          ubuntu@${BUILD_HOST} \
                          'sudo docker rm -f abode-test'
                    '''
                }
            }
        }

        stage('Job 3 - Production Deploy') {
            when {
                branch 'master'
            }
            steps {
                sshagent(credentials: ['abode-deploy-key']) {
                    sh '''
                        set -eu

                        # Transfer the exact image that passed testing.
                        ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                          ubuntu@${BUILD_HOST} \
                          "sudo docker save ${IMAGE_NAME}:${BUILD_NUMBER}" |
                        ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                          ubuntu@${PROD_HOST} \
                          'sudo docker load'

                        ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                          ubuntu@${PROD_HOST} \
                          "sudo docker rm -f abode-production >/dev/null 2>&1 || true; sudo docker run -d --name abode-production --restart unless-stopped -p 80:80 ${IMAGE_NAME}:${BUILD_NUMBER}"

                        passed=0
                        for attempt in $(seq 1 10); do
                            if ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                              ubuntu@${PROD_HOST} \
                              'curl -fsS http://127.0.0.1/ -o /dev/null'; then
                                passed=1
                                break
                            fi
                            sleep 2
                        done

                        if [ "$passed" -ne 1 ]; then
                            ssh -o BatchMode=yes -o StrictHostKeyChecking=yes \
                              ubuntu@${PROD_HOST} \
                              'sudo docker logs abode-production'
                            exit 1
                        fi
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Build/test pipeline succeeded.'
        }
        failure {
            echo 'Pipeline failed. Review the stage logs.'
        }
    }
}
