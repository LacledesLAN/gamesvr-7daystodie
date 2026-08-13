#!/bin/bash
set -euo pipefail

exec 3>&1
exec 1>&2

printf '## Build gamesvr-7daystodie\n\n'

created_image_tags=()
command_fence_open=false

record_image_tag() {
    local image_tag="$1"
    local existing_tag

    for existing_tag in "${created_image_tags[@]+"${created_image_tags[@]}"}"; do
        [[ "$existing_tag" == "$image_tag" ]] && return 0
    done
    created_image_tags+=("$image_tag")
}

run_fenced() {
    local command_status=0
    local escape_character=$'\033'

    printf '````````console\n'
    command_fence_open=true
    if "$@" 2>&1 | tr '\r' '\n' | sed -E "s/${escape_character}\\[[0-9;?]*[[:alpha:]]//g"; then
        command_status=${PIPESTATUS[0]}
    else
        command_status=${PIPESTATUS[0]}
    fi
    command_fence_open=false
    printf '````````\n\n'
    return "$command_status"
}

on_exit() {
    local exit_status=$?
    local cleanup_status=0

    trap - EXIT HUP INT TERM PIPE
    trap '' HUP INT TERM PIPE
    set +e
    if [[ "$command_fence_open" == true ]]; then
        printf '````````\n\n'
        command_fence_open=false
    fi
    if declare -F cleanup > /dev/null; then
        cleanup
        cleanup_status=$?
        if (( exit_status == 0 && cleanup_status != 0 )); then
            exit_status=$cleanup_status
        fi
    fi
    if (( ${#created_image_tags[@]} > 0 )); then
        printf '\n### Completed images\n\n' >&2
    fi
    exec 1>&3
    if (( ${#created_image_tags[@]} > 0 )); then
        printf '%s\n' "${created_image_tags[@]}" 2>/dev/null || true
    fi
    exit "$exit_status"
}

trap on_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

#######################################################################################################################
#######################################################################################################################
# GAME SERVER CONFIGURATION
# Modify these variables when copying this script to a new game server repository.
#######################################################################################################################
IMAGE_REPO="lacledeslan"
IMAGE_NAME="gamesvr-7daystodie"
DOCKERFILE_PATH='linux.Dockerfile'

# Automatically generated tags based on configuration
LOCAL_DOCKER_TAG="${IMAGE_NAME}:latest"
DOCKER_TAGS=(
    "$LOCAL_DOCKER_TAG"
    "${IMAGE_REPO}/${IMAGE_NAME}:latest"
)
PUBLISHING_DOCKER_TAGS=(
    "${IMAGE_REPO}/${IMAGE_NAME}:latest"
)

# Automatically determine the path to the test script
TEST_SCRIPT_PATH="./test-${IMAGE_NAME}.sh"
#######################################################################################################################
#######################################################################################################################

# Ensure DOCKER_TAGS is defined and not empty immediately
if (( ${#DOCKER_TAGS[@]} == 0 )); then
    printf "ERROR: No DOCKER_TAGS have been defined. Please specify at least one tag.\n" >&2
    exit 1
fi



#
# Parse command line options into a single indexed array
#
build_options=()

while (( "$#" > 0 ))
do
    case "$1" in
        --delta)                     build_options+=("--delta") ;;
        --enable-steamcmd-cache)     build_options+=("--enable-steamcmd-cache") ;;
        --disable-docker-cache)      build_options+=("--disable-docker-cache") ;;
        --progress-plain)            build_options+=("--progress-plain") ;;
        --skip-pull)                 build_options+=("--skip-pull") ;;
        --skip-tests)                build_options+=("--skip-tests") ;;
        --skip-push)                 build_options+=("--skip-push") ;;
        *)
            printf "Error: unknown option '%s'. Exiting.\n" "${1}" >&2
            exit 12
            ;;
    esac
    shift
done

# Helper function to check if a flag exists in the build_options array
has_option() {
    local target="$1"
    local opt
    for opt in "${build_options[@]+"${build_options[@]}"}"; do
        if [[ "$opt" == "$target" ]]; then
            return 0
        fi
    done
    return 1
}


#
# PREFLIGHT
#
for cmd in date docker git hostname sed tr; do
    if ! command -v "$cmd" > /dev/null 2>&1; then
        printf "ERROR: Required command '%s' is not installed or not in PATH.\n" "$cmd" >&2
        exit 1
    fi
done

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    printf "ERROR: The current directory is not a Git repository.\n" >&2
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    printf "ERROR: Docker is installed, but the current user cannot access the Docker daemon.\n" >&2
    exit 1
fi

if ! has_option "--skip-tests" && [[ ! -x "$TEST_SCRIPT_PATH" ]]; then
    printf "ERROR: Required test script is missing or not executable: %s\n" "$TEST_SCRIPT_PATH" >&2
    exit 1
fi

CURRENT_HOST=$(hostname)
GIT_REVISION=$(git rev-parse HEAD)
if [ -n "$(git status --porcelain)" ] || [ -n "$(git log '@{u}..HEAD' 2>/dev/null)" ]; then
    GIT_REVISION="${GIT_REVISION}-dirty"
fi

# Extract Git remote URL and normalize it to an HTTPS web URL format for labels
RAW_REMOTE=$(git config --get remote.origin.url || echo "unknown-remote")
if [[ "$RAW_REMOTE" == git@github.com:* ]]; then
    SOURCE_URL="https://github.com/${RAW_REMOTE#git@github.com:}"
    SOURCE_URL="${SOURCE_URL%.git}"
else
    SOURCE_URL="${RAW_REMOTE%.git}"
fi

printf "Building \`%s\` from \`%s\` (%s) on \`%s\`.\n\n" "${DOCKER_TAGS[0]}" "$GIT_REVISION" "$SOURCE_URL" "$CURRENT_HOST"


#
# Validate options
#
if has_option "--skip-tests" && ! has_option "--skip-push"; then
    printf "WARNING: --skip-tests was specified without --skip-push. The requested images will be pushed without testing.\n" >&2
fi

#
# Cleanup Function (Ensures cleanup happens even if tests or builds fail)
#
cleanup() {
    printf '### Cleanup\n\n'

    # Clean up dangling images dynamically using the resolved SOURCE_URL
    if [ "$SOURCE_URL" != "unknown-remote" ]; then
        local dangling_images
        dangling_images=$(docker images -q --filter "label=org.opencontainers.image.source=${SOURCE_URL}" --filter "dangling=true")
        if [ -n "$dangling_images" ]; then
            local dangling_image
            while IFS= read -r dangling_image; do
                run_fenced docker rmi "$dangling_image"
            done <<< "$dangling_images"
        fi
    fi

}

#
# Build the Docker image
#
docker_opts=()

if ! has_option "--skip-pull"; then
    docker_opts+=(--pull)
else
    printf "Skipping pulling the latest base image\n"
fi

if has_option "--enable-steamcmd-cache"; then
    printf "local SteamCMD cache is enabled\n"
    docker_opts+=(--build-arg ENABLE_STEAMCMD_CACHE="true")
fi

if has_option "--disable-docker-cache"; then
    printf "Docker cache layer matching is disabled (--no-cache)\n"
    docker_opts+=(--no-cache)
fi

if has_option "--progress-plain"; then
    printf "Plain Docker build progress is enabled (--progress=plain)\n"
    docker_opts+=(--progress=plain)
fi

docker_opts+=(
    --build-arg BUILD_NODE="$CURRENT_HOST"
    --build-arg GIT_REVISION="$GIT_REVISION"
)

for target_tag in "${DOCKER_TAGS[@]}"; do
    docker_opts+=(-t "$target_tag")
done

if has_option "--delta"; then
    printf "This build does not support delta-updates. Building full image.\n"
fi

printf '### Build\n\n'
run_fenced docker build . "${docker_opts[@]}" -f "$DOCKERFILE_PATH" --rm --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
for target_tag in "${DOCKER_TAGS[@]}"; do
    record_image_tag "$target_tag"
done


#
# Run tests for the Docker image unless skipped
#
printf '### Tests\n\n'

if ! has_option "--skip-tests"; then
    run_fenced "$TEST_SCRIPT_PATH" "$LOCAL_DOCKER_TAG"
else
    printf "Skipping tests.\n"
fi


#
# Push the Docker image to all configured tags unless skipped
#
printf '### Push\n\n'

if ! has_option "--skip-push"; then
    for target_tag in "${PUBLISHING_DOCKER_TAGS[@]}"; do
        printf "Pushing %s...\n" "$target_tag"
        run_fenced docker push "$target_tag"
    done
else
    printf "Skipping push operations\n"
fi

printf "**Job's Done**\n\n"
