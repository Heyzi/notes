#!/bin/bash

set -e

PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://localhost:9091}"

safe_get() {
    echo "${!1:-unknown}"
}

send_final_metrics() {
    local job_name="gitlab_pipeline"
    local instance="$(safe_get CI_PROJECT_PATH)"
    
    cat <<EOF | curl --silent --show-error --fail --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/${job_name}/instance/${instance}"
# HELP gitlab_ci_job_duration_seconds Duration of GitLab CI job
# TYPE gitlab_ci_job_duration_seconds gauge
gitlab_ci_job_duration_seconds{pipeline="$(safe_get CI_PIPELINE_ID)",job="$(safe_get CI_JOB_NAME)",stage="$(safe_get CI_JOB_STAGE)",repo="$(safe_get CI_PROJECT_NAME)",branch="$(safe_get CI_COMMIT_REF_NAME)"} ${duration}

# HELP gitlab_ci_job_status Status of GitLab CI job (1 for success, 0 for failure)
# TYPE gitlab_ci_job_status gauge
gitlab_ci_job_status{pipeline="$(safe_get CI_PIPELINE_ID)",job="$(safe_get CI_JOB_NAME)",stage="$(safe_get CI_JOB_STAGE)",repo="$(safe_get CI_PROJECT_NAME)",branch="$(safe_get CI_COMMIT_REF_NAME)"} ${job_status}

# HELP gitlab_ci_pipeline_executions_total Total number of pipeline executions
# TYPE gitlab_ci_pipeline_executions_total counter
gitlab_ci_pipeline_executions_total{pipeline="$(safe_get CI_PIPELINE_ID)",repo="$(safe_get CI_PROJECT_NAME)",branch="$(safe_get CI_COMMIT_REF_NAME)"} 1

# HELP gitlab_ci_job_queue_duration_seconds Time job spent in queue before starting
# TYPE gitlab_ci_job_queue_duration_seconds gauge
gitlab_ci_job_queue_duration_seconds{pipeline="$(safe_get CI_PIPELINE_ID)",job="$(safe_get CI_JOB_NAME)",stage="$(safe_get CI_JOB_STAGE)",repo="$(safe_get CI_PROJECT_NAME)",branch="$(safe_get CI_COMMIT_REF_NAME)"} ${queue_duration}
EOF
}

# Запуск скрипта мониторинга в фоновом режиме
./monitoring.sh &
MONITORING_PID=$!

# Время начала job
start_time=$(date +%s.%N)

# Время постановки job в очередь
queue_time=$(safe_get CI_JOB_QUEUED_AT)

# Выполнение основного скрипта job
"$@"
job_exit_code=$?

# Время окончания job
end_time=$(date +%s.%N)

# Остановка скрипта мониторинга
kill $MONITORING_PID

# Расчет времени выполнения
duration=$(echo "${end_time} - ${start_time}" | bc)

# Расчет времени ожидания в очереди
if [ "${queue_time}" != "unknown" ]; then
    queue_duration=$(echo "${start_time} - $(date -d "${queue_time}" +%s.%N)" | bc)
else
    queue_duration=0
fi

# Определение статуса job
job_status=$((job_exit_code == 0))

# Отправка финальных метрик
send_final_metrics

exit $job_exit_code
