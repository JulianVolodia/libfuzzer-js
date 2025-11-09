// Jenkinsfile for Continuous Fuzzing
// Place this file as 'Jenkinsfile' in your repository root

pipeline {
    agent any

    // Build parameters
    parameters {
        choice(
            name: 'FUZZ_DURATION',
            choices: ['300', '600', '1800', '3600', '14400'],
            description: 'Fuzzing duration in seconds'
        )
        string(
            name: 'MAX_LEN',
            defaultValue: '10000',
            description: 'Maximum input length'
        )
        string(
            name: 'TIMEOUT',
            defaultValue: '10',
            description: 'Timeout per fuzzing iteration (seconds)'
        )
    }

    // Environment variables
    environment {
        LIBFUZZER_BUILD_DIR = "${env.HOME}/fuzzer_build"
        CRASHES_DIR = "${WORKSPACE}/crashes"
        CORPUS_DIR = "${WORKSPACE}/corpus"
    }

    // Build stages
    stages {
        stage('Setup') {
            steps {
                echo "Setting up fuzzing environment..."

                sh '''
                    # Clean previous artifacts
                    rm -rf crashes/* corpus_temp/*

                    # Create directories
                    mkdir -p ${CRASHES_DIR}
                    mkdir -p ${CORPUS_DIR}
                '''
            }
        }

        stage('Build libFuzzer') {
            steps {
                script {
                    // Check if libFuzzer is already built
                    if (!fileExists("${env.LIBFUZZER_BUILD_DIR}/Fuzzer/libFuzzer.a")) {
                        echo "Building libFuzzer..."
                        sh '''
                            mkdir -p ${LIBFUZZER_BUILD_DIR}
                            cd ${LIBFUZZER_BUILD_DIR}
                            svn co https://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer Fuzzer
                            cd Fuzzer
                            ./build.sh
                        '''
                    } else {
                        echo "libFuzzer already built, skipping..."
                    }
                }
            }
        }

        stage('Build Fuzzer') {
            steps {
                sh '''
                    export LIBFUZZER_A_PATH=${LIBFUZZER_BUILD_DIR}/Fuzzer/libFuzzer.a
                    make clean || true
                    make
                '''
            }
        }

        stage('Parallel Fuzzing') {
            parallel {
                stage('Fuzz Parser') {
                    steps {
                        script {
                            fuzzTarget(
                                'parser',
                                'fuzz/fuzz_parser.js',
                                params.FUZZ_DURATION
                            )
                        }
                    }
                }

                stage('Fuzz Validator') {
                    steps {
                        script {
                            fuzzTarget(
                                'validator',
                                'fuzz/fuzz_validator.js',
                                params.FUZZ_DURATION
                            )
                        }
                    }
                }

                stage('Fuzz API') {
                    steps {
                        script {
                            fuzzTarget(
                                'api',
                                'fuzz/fuzz_api.js',
                                params.FUZZ_DURATION
                            )
                        }
                    }
                }
            }
        }

        stage('Analyze Results') {
            steps {
                script {
                    def crashesFound = sh(
                        script: 'find ${CRASHES_DIR} -name "crash-*" | wc -l',
                        returnStdout: true
                    ).trim()

                    echo "Total crashes found: ${crashesFound}"

                    if (crashesFound.toInteger() > 0) {
                        currentBuild.result = 'UNSTABLE'
                        echo "WARNING: Fuzzing found ${crashesFound} crashes!"

                        // List all crashes
                        sh 'find ${CRASHES_DIR} -name "crash-*" -ls'
                    } else {
                        echo "SUCCESS: No crashes found"
                    }
                }
            }
        }

        stage('Generate Report') {
            steps {
                sh '''
                    cat > fuzzing_report.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Fuzzing Report - Build #${BUILD_NUMBER}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        .crash { background-color: #ffcccc; }
        .success { background-color: #ccffcc; }
    </style>
</head>
<body>
    <h1>Fuzzing Report</h1>
    <p><strong>Build:</strong> #${BUILD_NUMBER}</p>
    <p><strong>Date:</strong> $(date)</p>
    <p><strong>Duration:</strong> ${FUZZ_DURATION} seconds</p>

    <h2>Results</h2>
    <table>
        <tr>
            <th>Target</th>
            <th>Crashes Found</th>
            <th>Status</th>
        </tr>
        <tr class="$([ $(find ${CRASHES_DIR}/parser -name "crash-*" 2>/dev/null | wc -l) -gt 0 ] && echo crash || echo success)">
            <td>Parser</td>
            <td>$(find ${CRASHES_DIR}/parser -name "crash-*" 2>/dev/null | wc -l)</td>
            <td>$([ $(find ${CRASHES_DIR}/parser -name "crash-*" 2>/dev/null | wc -l) -gt 0 ] && echo "⚠️ Crashes" || echo "✅ OK")</td>
        </tr>
        <tr class="$([ $(find ${CRASHES_DIR}/validator -name "crash-*" 2>/dev/null | wc -l) -gt 0 ] && echo crash || echo success)">
            <td>Validator</td>
            <td>$(find ${CRASHES_DIR}/validator -name "crash-*" 2>/dev/null | wc -l)</td>
            <td>$([ $(find ${CRASHES_DIR}/validator -name "crash-*" 2>/dev/null | wc -l) -gt 0 ] && echo "⚠️ Crashes" || echo "✅ OK")</td>
        </tr>
        <tr class="$([ $(find ${CRASHES_DIR}/api -name "crash-*" 2>/dev/null | wc -l) -gt 0 ] && echo crash || echo success)">
            <td>API</td>
            <td>$(find ${CRASHES_DIR}/api -name "crash-*" 2>/dev/null | wc -l)</td>
            <td>$([ $(find ${CRASHES_DIR}/api -name "crash-*" 2>/dev/null | wc -l) -gt 0 ] && echo "⚠️ Crashes" || echo "✅ OK")</td>
        </tr>
    </table>

    <h2>Corpus Statistics</h2>
    <table>
        <tr>
            <th>Target</th>
            <th>Files</th>
            <th>Total Size</th>
        </tr>
        <tr>
            <td>Parser</td>
            <td>$(find ${CORPUS_DIR}/parser -type f 2>/dev/null | wc -l)</td>
            <td>$(du -sh ${CORPUS_DIR}/parser 2>/dev/null | cut -f1 || echo "0")</td>
        </tr>
        <tr>
            <td>Validator</td>
            <td>$(find ${CORPUS_DIR}/validator -type f 2>/dev/null | wc -l)</td>
            <td>$(du -sh ${CORPUS_DIR}/validator 2>/dev/null | cut -f1 || echo "0")</td>
        </tr>
        <tr>
            <td>API</td>
            <td>$(find ${CORPUS_DIR}/api -type f 2>/dev/null | wc -l)</td>
            <td>$(du -sh ${CORPUS_DIR}/api 2>/dev/null | cut -f1 || echo "0")</td>
        </tr>
    </table>
</body>
</html>
EOF
                '''

                publishHTML([
                    reportDir: '.',
                    reportFiles: 'fuzzing_report.html',
                    reportName: 'Fuzzing Report',
                    keepAll: true
                ])
            }
        }
    }

    // Post-build actions
    post {
        always {
            // Archive crashes
            archiveArtifacts artifacts: 'crashes/**/*', allowEmptyArchive: true

            // Archive corpus
            archiveArtifacts artifacts: 'corpus/**/*', allowEmptyArchive: true
        }

        unstable {
            emailext(
                subject: "Fuzzing found crashes - Build #${env.BUILD_NUMBER}",
                body: """
                    Fuzzing has discovered crashes in build #${env.BUILD_NUMBER}.

                    Please review the fuzzing report and investigate the crashes.

                    Build URL: ${env.BUILD_URL}
                """,
                to: '${DEFAULT_RECIPIENTS}'
            )
        }

        success {
            echo 'Fuzzing completed successfully with no crashes!'
        }

        cleanup {
            // Clean up temporary files
            sh 'rm -rf corpus_temp'
        }
    }
}

// Helper function to fuzz a specific target
def fuzzTarget(String name, String target, String duration) {
    sh """
        mkdir -p ${CRASHES_DIR}/${name}
        mkdir -p ${CORPUS_DIR}/${name}

        echo "Fuzzing ${name} for ${duration} seconds..."

        timeout ${duration} ./jsfuzzer \\
            --js=${target} \\
            ${CORPUS_DIR}/${name}/ \\
            -max_len=${params.MAX_LEN} \\
            -timeout=${params.TIMEOUT} \\
            -artifact_prefix=${CRASHES_DIR}/${name}/ || true

        echo "Fuzzing ${name} completed"

        # Check for crashes
        if ls ${CRASHES_DIR}/${name}/crash-* 1> /dev/null 2>&1; then
            echo "WARNING: Crashes found in ${name}"
            ls -la ${CRASHES_DIR}/${name}/
        fi
    """
}
