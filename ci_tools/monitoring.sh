#!/bin/bash

PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://localhost:9091}"
METRIC_INTERVAL=${METRIC_INTERVAL:-60}

safe_get() {
    echo "${!1:-unknown}"
}

send_metrics() {
    local job_name="gitlab_pipeline"
    local instance="$(safe_get CI_PROJECT_PATH)"
    
    if [[ "$(uname)" == "Linux" ]]; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
        memory_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    else
        cpu_usage=0
        memory_usage=0
    fi

    cat <<EOF | curl --silent --show-error --fail --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/${job_name}/instance/${instance}"
# HELP gitlab_ci_job_cpu_usage_percent CPU usage of GitLab CI job
# TYPE gitlab_ci_job_cpu_usage_percent gauge
gitlab_ci_job_cpu_usage_percent{pipeline="$(safe_get CI_PIPELINE_ID)",job="$(safe_get CI_JOB_NAME)",stage="$(safe_get CI_JOB_STAGE)",repo="$(safe_get CI_PROJECT_NAME)",branch="$(safe_get CI_COMMIT_REF_NAME)"} ${cpu_usage}

# HELP gitlab_ci_job_memory_usage_percent Memory usage of GitLab CI job
# TYPE gitlab_ci_job_memory_usage_percent gauge
gitlab_ci_job_memory_usage_percent{pipeline="$(safe_get CI_PIPELINE_ID)",job="$(safe_get CI_JOB_NAME)",stage="$(safe_get CI_JOB_STAGE)",repo="$(safe_get CI_PROJECT_NAME)",branch="$(safe_get CI_COMMIT_REF_NAME)"} ${memory_usage}
EOF
}

while true; do
    send_metrics
    sleep $METRIC_INTERVAL
done
