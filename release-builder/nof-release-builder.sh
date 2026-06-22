#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="nof-apps"
ROOT_DIR="${NOF_RELEASE_ROOT:-$HOME/nof-release-builder}"
WORK_DIR="$ROOT_DIR/work"
EVIDENCE_DIR="$ROOT_DIR/evidence"
LOG_DIR="$ROOT_DIR/logs"
STATE_DIR="$ROOT_DIR/state"
CONFIG_ENV="$HOME/.config/nof-release-builder/env"
LOCK_DIR="$ROOT_DIR/.lock"
CONTROL_REPO_URL="${NOF_RELEASE_CONTROL_REPO_URL:-https://github.com/teanores/nof-infra.git}"
CONTROL_MANIFEST_PATH="${NOF_RELEASE_CONTROL_MANIFEST_PATH:-environments/hbl/desired-state.tsv}"

usage() {
  cat <<'USAGE'
Usage:
  nof-release-builder.sh list
  nof-release-builder.sh deploy <service> <git-ref>
  nof-release-builder.sh sync <control-git-ref>

Services:
  nof-mp
  nof-tt
  nof-ht

The builder reads a GitHub read-only token from:
  NOF_RELEASE_GITHUB_TOKEN
or:
  ~/.config/nof-release-builder/env

Do not print secrets in logs, tickets or chat.

Manifest format for sync mode:
  service<TAB>git-ref<TAB>enabled

Sync mode requires an explicit service allowlist:
  NOF_RELEASE_SYNC_APPROVED_SERVICES=nof-mp,nof-tt

Unset or empty NOF_RELEASE_SYNC_APPROVED_SERVICES blocks all enabled manifest rows.

Routine product-agent deploys should use the GitHub runner workflow:
  gh workflow run release-builder.yml -R teanores/nof-infra

Manual/emergency deploys remain available, but require:
  NOF_RELEASE_MANUAL_OVERRIDE=1
  NOF_RELEASE_APPROVAL_ID=<current-chat-owner-approval-or-tracker-evidence-id>
USAGE
}

list_services() {
  cat <<'SERVICES'
nof-mp
nof-tt
nof-ht
SERVICES
}

load_env() {
  if [[ -f "$CONFIG_ENV" ]]; then
    # shellcheck source=/dev/null
    set -a
    source "$CONFIG_ENV"
    set +a
  fi
}

require_token() {
  if [[ -z "${NOF_RELEASE_GITHUB_TOKEN:-}" ]]; then
    echo "ERROR: NOF_RELEASE_GITHUB_TOKEN is not set. Configure ~/.config/nof-release-builder/env." >&2
    exit 2
  fi
}

require_release_invocation_context() {
  local command="$1"
  local approval_id="${NOF_RELEASE_APPROVAL_ID:-}"

  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    if [[ -z "${approval_id// }" ]]; then
      echo "ERROR: NOF_RELEASE_APPROVAL_ID is required for GitHub runner release-builder $command." >&2
      exit 64
    fi
    echo "==> Release invocation: github-runner approval=$approval_id"
    return 0
  fi

  if [[ "${NOF_RELEASE_MANUAL_OVERRIDE:-}" == "1" ]]; then
    if [[ -z "${approval_id// }" ]]; then
      echo "ERROR: NOF_RELEASE_APPROVAL_ID is required for manual/emergency release-builder $command." >&2
      exit 64
    fi
    echo "==> Release invocation: manual/emergency approval=$approval_id"
    return 0
  fi

  cat >&2 <<EOF
ERROR: release-builder $command refused without an explicit invocation context.

Routine product-agent deploys must use the GitHub runner flow:
  gh workflow run release-builder.yml -R teanores/nof-infra

Manual SSH/local release-builder remains available for critical or emergency work,
but it must be explicitly approved and marked:
  NOF_RELEASE_MANUAL_OVERRIDE=1
  NOF_RELEASE_APPROVAL_ID=<current-chat-owner-approval-or-tracker-evidence-id>

See docs/runbooks/github-runner-release-builder.md.
EOF
  exit 78
}

make_askpass() {
  local askpass_file="$ROOT_DIR/.git-askpass.sh"
  cat > "$askpass_file" <<'ASKPASS'
#!/usr/bin/env bash
case "$1" in
  *Username*) printf '%s\n' "x-access-token" ;;
  *Password*) printf '%s\n' "$NOF_RELEASE_GITHUB_TOKEN" ;;
  *) printf '\n' ;;
esac
ASKPASS
  chmod 700 "$askpass_file"
  printf '%s\n' "$askpass_file"
}

service_config() {
  local service="$1"
  case "$service" in
    nof-tt)
      REPO_URL="https://github.com/teanores/nof-tt.git"
      SOURCE_SUBDIR="."
      DOCKERFILE_SUBPATH="apps/web/Dockerfile"
      IMAGE_REPOSITORY="localhost:32000/nof-tt"
      RELEASE_NAME="nof-tt"
      CHART_REPO_URL="https://github.com/teanores/nof-infra.git"
      CHART_SUBDIR="helm/nof-tt"
      MIGRATION_MODE="none"
      MIGRATION_COMMAND=""
      MIGRATION_SECRET_REFS=""
      MIGRATION_CONFIGMAP_REFS=""
      MIGRATION_TIMEOUT_SECONDS="300"
      ;;
    nof-mp)
      REPO_URL="https://github.com/teanores/nof-mp.git"
      SOURCE_SUBDIR="."
      DOCKERFILE_SUBPATH="apps/web/Dockerfile"
      IMAGE_REPOSITORY="localhost:32000/nof-mp"
      RELEASE_NAME="nof-mp"
      CHART_REPO_URL="https://github.com/teanores/nof-infra.git"
      CHART_SUBDIR="helm/nof-mp"
      MIGRATION_MODE="none"
      MIGRATION_COMMAND=""
      MIGRATION_SECRET_REFS=""
      MIGRATION_CONFIGMAP_REFS=""
      MIGRATION_TIMEOUT_SECONDS="300"
      ;;
    nof-ht)
      REPO_URL="https://github.com/teanores/nof-ht.git"
      SOURCE_SUBDIR="."
      DOCKERFILE_SUBPATH="Dockerfile"
      IMAGE_REPOSITORY="localhost:32000/nof-ht"
      RELEASE_NAME="nof-ht"
      CHART_REPO_URL="https://github.com/teanores/nof-infra.git"
      CHART_SUBDIR="helm/nof-ht"
      MIGRATION_MODE="job"
      MIGRATION_COMMAND="npm run db:migrate:release"
      MIGRATION_SECRET_REFS="nof-ht-secrets nof-ht-oauth-secrets"
      MIGRATION_CONFIGMAP_REFS="nof-ht-config"
      MIGRATION_TIMEOUT_SECONDS="300"
      ;;
    *)
      echo "ERROR: unknown service '$service'." >&2
      exit 64
      ;;
  esac
}

require_migration_gate_ready() {
  local service="$1"
  local migration_mode="$2"

  case "$migration_mode" in
    none)
      return 0
      ;;
    job)
      if [[ -z "${MIGRATION_COMMAND:-}" ]]; then
        echo "ERROR: $service declares MIGRATION_MODE=job but MIGRATION_COMMAND is empty." >&2
        exit 78
      fi
      return 0
      ;;
    *)
      echo "ERROR: unsupported migration mode '$migration_mode' for $service." >&2
      exit 64
      ;;
  esac
}

sync_service_is_approved() {
  local service="$1"
  local allowlist="${NOF_RELEASE_SYNC_APPROVED_SERVICES:-}"
  local approved

  if [[ -z "$allowlist" ]]; then
    return 1
  fi

  IFS=',' read -r -a approved <<< "$allowlist"
  for item in "${approved[@]}"; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    if [[ "$item" == "$service" ]]; then
      return 0
    fi
  done

  return 1
}

redact_secrets_from_stream() {
  sed -E \
    -e 's#postgres(ql)?://[^[:space:]]+#postgres://<redacted>#g' \
    -e 's#(PASSWORD|TOKEN|SECRET|DATABASE_URL)=([^[:space:]]+)#\1=<redacted>#g'
}

append_env_from_refs() {
  local refs="$1"
  local ref_kind="$2"
  local ref
  for ref in $refs; do
    case "$ref_kind" in
      secret)
        cat <<EOF
            - secretRef:
                name: $ref
EOF
        ;;
      configmap)
        cat <<EOF
            - configMapRef:
                name: $ref
EOF
        ;;
      *)
        echo "ERROR: unsupported envFrom ref kind '$ref_kind'." >&2
        exit 64
        ;;
    esac
  done
}

run_migration_gate() {
  local service="$1"
  local image="$2"
  local image_tag="$3"
  local app_version="$4"

  case "$MIGRATION_MODE" in
    none)
      MIGRATION_EVIDENCE="mode=none"
      echo "==> Migration gate: not required for $service"
      return 0
      ;;
    job)
      ;;
    *)
      echo "ERROR: unsupported migration mode '$MIGRATION_MODE' for $service." >&2
      exit 64
      ;;
  esac

  local job_name="${service}-migrate-${image_tag}"
  local migration_log="$LOG_DIR/${service}-${image_tag}-migration.log"
  local manifest_file="$WORK_DIR/$service/migration-job.yaml"

  mkdir -p "$(dirname "$manifest_file")" "$LOG_DIR"

  cat > "$manifest_file" <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
  namespace: $NAMESPACE
  labels:
    app.kubernetes.io/name: $service
    app.kubernetes.io/component: migration
    nof.forgath.ru/release-image-tag: "$image_tag"
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app.kubernetes.io/name: $service
        app.kubernetes.io/component: migration
    spec:
      restartPolicy: Never
      containers:
        - name: migration
          image: "$image"
          imagePullPolicy: Always
          command: ["/bin/sh", "-lc"]
          args:
            - "$MIGRATION_COMMAND"
          env:
            - name: NEXT_PUBLIC_APP_VERSION
              value: "$app_version"
          envFrom:
EOF
  append_env_from_refs "$MIGRATION_SECRET_REFS" secret >> "$manifest_file"
  append_env_from_refs "$MIGRATION_CONFIGMAP_REFS" configmap >> "$manifest_file"

  echo "==> Migration gate: running $job_name before Helm upgrade"
  sudo microk8s kubectl delete job "$job_name" -n "$NAMESPACE" --ignore-not-found=true >/dev/null
  sudo microk8s kubectl apply -f "$manifest_file"

  if ! sudo microk8s kubectl wait --for=condition=complete "job/$job_name" -n "$NAMESPACE" --timeout="${MIGRATION_TIMEOUT_SECONDS}s"; then
    echo "ERROR: migration job $job_name failed or timed out before Helm upgrade." >&2
    sudo microk8s kubectl logs "job/$job_name" -n "$NAMESPACE" --tail=200 2>&1 | redact_secrets_from_stream | tee "$migration_log" >&2 || true
    exit 70
  fi

  sudo microk8s kubectl logs "job/$job_name" -n "$NAMESPACE" --tail=500 2>&1 | redact_secrets_from_stream | tee "$migration_log" >/dev/null || true
  MIGRATION_EVIDENCE="mode=job job=$job_name log=$migration_log"
  echo "==> Migration gate: $job_name completed"
}

sanitize_ref() {
  local ref="$1"
  if [[ -z "$ref" || "$ref" == -* || "$ref" =~ [[:space:]\;\&\|\`\$\<\>] ]]; then
    echo "ERROR: unsafe or empty git ref." >&2
    exit 64
  fi
}

app_version_from_ref() {
  local service="$1"
  local ref="$2"
  if [[ "$ref" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    printf '%s\n' "${ref#v}"
    return 0
  fi

  case "$service" in
    nof-mp|nof-tt|nof-ht)
      echo "ERROR: $service production deploys must use a semver tag ref such as v0.2.13. Raw commit refs would leak into NEXT_PUBLIC_APP_VERSION." >&2
      exit 64
      ;;
    *)
      echo "ERROR: cannot derive app version for $service from ref '$ref'." >&2
      exit 64
      ;;
  esac
}

set_chart_app_version() {
  local chart_path="$1"
  local app_version="$2"
  local chart_file="$chart_path/Chart.yaml"

  if [[ ! -f "$chart_file" ]]; then
    echo "ERROR: Helm Chart.yaml not found: $chart_file" >&2
    exit 66
  fi

  local chart_tmp
  chart_tmp="$(mktemp)"
  if ! awk -v app_version="$app_version" '
    BEGIN { count = 0 }
    /^appVersion:[[:space:]]*/ {
      print "appVersion: \"" app_version "\""
      count++
      next
    }
    { print }
    END { if (count != 1) exit 3 }
  ' "$chart_file" > "$chart_tmp"; then
    rm -f "$chart_tmp"
    echo "ERROR: expected exactly one appVersion field in $chart_file" >&2
    exit 66
  fi
  mv "$chart_tmp" "$chart_file"
}

prepare_repo() {
  local url="$1"
  local ref="$2"
  local dir="$3"

  mkdir -p "$(dirname "$dir")"
  if [[ ! -d "$dir/.git" ]]; then
    rm -rf "$dir"
    git clone "$url" "$dir"
  fi

  git -C "$dir" remote set-url origin "$url"
  git -C "$dir" fetch --prune origin
  local checkout_ref="$ref"
  if git -C "$dir" rev-parse --verify --quiet "origin/$ref" >/dev/null; then
    checkout_ref="origin/$ref"
  fi
  git -C "$dir" checkout --detach "$checkout_ref"
  git -C "$dir" reset --hard
  git -C "$dir" clean -fdx
}

deploy_service() {
  local service="$1"
  local ref="$2"
  sanitize_ref "$ref"
  require_release_invocation_context "deploy"
  service_config "$service"
  load_env
  require_token

  mkdir -p "$WORK_DIR" "$EVIDENCE_DIR" "$LOG_DIR" "$STATE_DIR"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "ERROR: another deploy is already running." >&2
    exit 75
  fi
  trap 'rm -rf "$LOCK_DIR"' EXIT

  local askpass
  askpass="$(make_askpass)"
  export GIT_ASKPASS="$askpass"
  export GIT_TERMINAL_PROMPT=0

  local started_at
  started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local src_dir="$WORK_DIR/$service/source"
  local chart_dir="$WORK_DIR/$service/chart-source"

  echo "==> Fetching source for $service at ref $ref"
  prepare_repo "$REPO_URL" "$ref" "$src_dir"

  echo "==> Fetching chart for $service"
  prepare_repo "$CHART_REPO_URL" "origin/main" "$chart_dir"

  local commit
  commit="$(git -C "$src_dir" rev-parse --short HEAD)"
  local full_commit
  full_commit="$(git -C "$src_dir" rev-parse HEAD)"
  local image_tag="$commit"
  local app_version
  app_version="$(app_version_from_ref "$service" "$ref")"
  local chart_path="$chart_dir/$CHART_SUBDIR"
  local dockerfile_path="$src_dir/$DOCKERFILE_SUBPATH"
  local context_path="$src_dir/$SOURCE_SUBDIR"

  if [[ ! -f "$dockerfile_path" ]]; then
    echo "ERROR: Dockerfile not found for $service: $dockerfile_path" >&2
    exit 66
  fi
  if [[ ! -d "$chart_path" ]]; then
    echo "ERROR: Helm chart not found for $service: $chart_path" >&2
    exit 66
  fi

  require_migration_gate_ready "$service" "$MIGRATION_MODE"
  set_chart_app_version "$chart_path" "$app_version"

  echo "==> Building $IMAGE_REPOSITORY:$image_tag"
  sudo docker build \
    --build-arg "NEXT_PUBLIC_APP_VERSION=$app_version" \
    -t "$IMAGE_REPOSITORY:$image_tag" \
    -t "$IMAGE_REPOSITORY:latest" \
    -f "$dockerfile_path" \
    "$context_path"
  sudo docker push "$IMAGE_REPOSITORY:$image_tag"
  sudo docker push "$IMAGE_REPOSITORY:latest"

  run_migration_gate "$service" "$IMAGE_REPOSITORY:$image_tag" "$image_tag" "$app_version"

  echo "==> Deploying release $RELEASE_NAME"
  sudo microk8s helm3 upgrade --install "$RELEASE_NAME" "$chart_path" \
    --namespace "$NAMESPACE" \
    --set "image.repository=$IMAGE_REPOSITORY" \
    --set "image.tag=$image_tag" \
    --set "appVersion=$app_version" \
    --wait --timeout 180s

  sudo microk8s kubectl rollout status "deployment/$RELEASE_NAME" -n "$NAMESPACE" --timeout=180s

  local helm_revision
  helm_revision="$(sudo microk8s helm3 status "$RELEASE_NAME" -n "$NAMESPACE" --output json | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')"
  local evidence_file="$EVIDENCE_DIR/${service}-${commit}-$(date -u +%Y%m%dT%H%M%SZ).txt"
  local rollback_command
  if (( helm_revision > 1 )); then
    rollback_command="sudo microk8s helm3 rollback $RELEASE_NAME $((helm_revision - 1)) -n $NAMESPACE --wait --timeout 180s"
  else
    rollback_command="first revision: disable this service in desired-state, restore the previous gateway/upstream if needed, then run sudo microk8s helm3 uninstall $RELEASE_NAME -n $NAMESPACE"
  fi

  {
    echo "service=$service"
    echo "source_ref=$ref"
    echo "app_version=$app_version"
    echo "commit=$full_commit"
    echo "image=$IMAGE_REPOSITORY:$image_tag"
    echo "release=$RELEASE_NAME"
    echo "namespace=$NAMESPACE"
    echo "migration=$MIGRATION_EVIDENCE"
    echo "helm_revision=$helm_revision"
    echo "started_at=$started_at"
    echo "completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "rollback=$rollback_command"
  } > "$evidence_file"

  echo "==> Done. Evidence: $evidence_file"
}

sync_from_manifest() {
  local control_ref="$1"
  sanitize_ref "$control_ref"
  require_release_invocation_context "sync"
  load_env
  require_token

  mkdir -p "$WORK_DIR" "$EVIDENCE_DIR" "$LOG_DIR" "$STATE_DIR"

  local askpass
  askpass="$(make_askpass)"
  export GIT_ASKPASS="$askpass"
  export GIT_TERMINAL_PROMPT=0

  local control_dir="$WORK_DIR/control/source"
  echo "==> Fetching release control manifest at ref $control_ref"
  prepare_repo "$CONTROL_REPO_URL" "$control_ref" "$control_dir"

  local manifest="$control_dir/$CONTROL_MANIFEST_PATH"
  if [[ ! -f "$manifest" ]]; then
    echo "ERROR: release manifest not found: $CONTROL_MANIFEST_PATH" >&2
    exit 66
  fi

  local line service ref enabled state_file current_state source_dir desired_state
  while IFS=$'\t' read -r service ref enabled || [[ -n "${service:-}" ]]; do
    [[ -z "${service:-}" || "$service" == \#* ]] && continue
    if [[ "$enabled" != "true" ]]; then
      echo "==> Skipping $service: enabled=$enabled"
      continue
    fi
    if ! sync_service_is_approved "$service"; then
      echo "==> Skipping $service: not in NOF_RELEASE_SYNC_APPROVED_SERVICES"
      continue
    fi
    sanitize_ref "$ref"
    service_config "$service"
    state_file="$STATE_DIR/$service.ref"
    current_state=""
    [[ -f "$state_file" ]] && current_state="$(cat "$state_file")"
    source_dir="$WORK_DIR/$service/source"
    prepare_repo "$REPO_URL" "$ref" "$source_dir"
    desired_state="$(git -C "$source_dir" rev-parse HEAD)"
    if [[ "$current_state" == "$desired_state" ]]; then
      echo "==> Skipping $service: commit unchanged ($ref @ ${desired_state:0:7})"
      continue
    fi
    "$0" deploy "$service" "$ref"
    printf '%s\n' "$desired_state" > "$state_file"
  done < "$manifest"
}

main() {
  local command="${1:-}"
  case "$command" in
    list)
      list_services
      ;;
    deploy)
      if [[ $# -ne 3 ]]; then
        usage >&2
        exit 64
      fi
      deploy_service "$2" "$3"
      ;;
    sync)
      if [[ $# -ne 2 ]]; then
        usage >&2
        exit 64
      fi
      sync_from_manifest "$2"
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      echo "ERROR: unknown command '$command'." >&2
      usage >&2
      exit 64
      ;;
  esac
}

if [[ "${NOF_RELEASE_BUILDER_SOURCE_ONLY:-}" != "1" ]]; then
  main "$@"
fi
