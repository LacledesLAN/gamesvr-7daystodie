#!/bin/bash
set -euo pipefail

#######################################################################################################################
#######################################################################################################################
# GAME SERVER CONFIGURATION
# Modify these variables when copying this script to a new game server repository.
#######################################################################################################################
IMAGE_REPO="lacledeslan"
IMAGE_NAME="gamesvr-7daystodie"
DOCKERFILE_PATH='linux.Dockerfile'
DOCKER_TEST_COMMAND=(/app/startserver.sh -configfile=serverconfig.xml)

# Automatically generated tags based on configuration
DOCKER_TAGS=(
    "${IMAGE_REPO}/${IMAGE_NAME}:latest"
)

# Automatically determine the path to the test script
TEST_SCRIPT_PATH="./tests/test-${IMAGE_NAME}.sh"
#######################################################################################################################
#######################################################################################################################

# Ensure DOCKER_TAGS is defined and not empty immediately
if (( ${#DOCKER_TAGS[@]} == 0 )); then
    printf "ERROR: No DOCKER_TAGS have been defined. Please specify at least one tag.\n" >&2
    exit 1
fi



#
# PREFLIGHT
#
CURRENT_HOST=$(hostname 2>/dev/null || echo "unknown-host")

# Verify required command-line tools exist
for cmd in git docker; do
    if ! command -v "$cmd" &> /dev/null; then
        printf "ERROR: %s is not installed or not in your PATH.\n" "${cmd^}" >&2
        exit 1
    fi
done

# Verify current workspace is a git repository
if ! git rev-parse --git-dir &> /dev/null; then
    printf "ERROR: The current directory is not a Git repository.\n" >&2
    exit 1
fi

if ! docker info &> /dev/null; then
    printf "ERROR: Docker is installed, but the current user cannot access the Docker daemon.\n" >&2
    exit 1
fi

SOURCE_COMMIT=$(git rev-parse --short HEAD)$([ -n "$(git status --porcelain)" ] && echo "-dirty")

# Extract Git remote URL and normalize it to an HTTPS web URL format for labels
RAW_REMOTE=$(git config --get remote.origin.url || echo "unknown-remote")
if [[ "$RAW_REMOTE" == git@github.com:* ]]; then
    SOURCE_URL="https://github.com/${RAW_REMOTE#git@github.com:}"
    SOURCE_URL="${SOURCE_URL%.git}"
else
    SOURCE_URL="${RAW_REMOTE%.git}"
fi

printf "# Building %s from \`%s\` (%s) on %s\n" "${DOCKER_TAGS[0]}" "$SOURCE_COMMIT" "$SOURCE_URL" "$CURRENT_HOST"


#
# Parse command line options using descriptive booleans
#
delete_built_image=false    # Deletes the newly built image locally during the exit cleanup phase
delta_updates=false         # Indicates a delta-style build (unsupported, prints a warning)
enable_steamcmd_cache=false # Passes a build argument to Docker to leverage a localized SteamCMD cache layer
skip_docker_cache=false     # Forces Docker to build the image from scratch without using cached layers
skip_pull=false             # Prevents Docker from pulling the latest remote base image before building
skip_push=false             # Prevents pushing the finished tags to Docker Hub/registries
skip_tests=false            # Bypasses the script-level validation tests usually executed post-build

while (( "$#" > 0 ))
do
    case "$1" in
        --delete-built-image)       delete_built_image=true ;;
        -d|--delta)                 delta_updates=true ;;
        --enable-steamcmd-cache)    enable_steamcmd_cache=true ;;
        --no-docker-cache)          skip_docker_cache=true ;;
        --skip-pull)                skip_pull=true ;;
        --skip-push-dockerhub|--skip-push) skip_push=true ;;
        --skip-tests)               skip_tests=true ;;
        *)
            printf "Error: unknown option '%s'. Exiting.\n" "${1}" >&2
            exit 12
            ;;
    esac
    shift
done


#
# Validate options
#
if $skip_tests && ! $skip_push; then
    printf "ERROR: Cannot skip tests while pushing to a remote registry is enabled.\n" >&2
    printf "Please either run tests or include --skip-push.\n" >&2
    exit 1
fi

if $delete_built_image && $skip_push; then
    printf "\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n" >&2
    printf "WARNING: You have selected both --delete-built-image and --skip-push.\n" >&2
    printf "The image will be built, but it will NOT be pushed and WILL be deleted locally.\n" >&2
    printf "This means the build will leave no lasting artifact.\n" >&2
    printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n" >&2
    printf "Continuing in 5 seconds... Press Ctrl+C to abort.\n\n" >&2
    sleep 5
fi


#
# Cleanup Function (Ensures cleanup happens even if tests or builds fail)
#
cleanup() {
    printf "\n## Running Post-Build Cleanup\n"

    # Clean up dangling images dynamically using the resolved SOURCE_URL
    if [ "$SOURCE_URL" != "unknown-remote" ]; then
        local dangling_images
        dangling_images=$(docker images -q --filter "label=org.opencontainers.image.source=${SOURCE_URL}" --filter "dangling=true")
        if [ -n "$dangling_images" ]; then
            echo "$dangling_images" | xargs -r docker rmi
        fi
    fi

    # Conditionally delete the built/tagged images if opt-in flag was provided
    if $delete_built_image; then
        for target_tag in "${DOCKER_TAGS[@]}"; do
            printf "Deleting local image: %s\n" "$target_tag"
            docker rmi "$target_tag" || true
        done
    fi
}
# Register the cleanup function to trigger on script exit
trap cleanup EXIT


#
# Build the Docker image
#
docker_opts=()

if ! $skip_pull; then
    docker_opts+=(--pull)
else
    printf "Skipping pulling the latest base image\n"
fi

if $enable_steamcmd_cache; then
    printf "local SteamCMD cache is enabled\n"
    docker_opts+=(--build-arg ENABLE_STEAMCMD_CACHE="true")
fi

if $skip_docker_cache; then
    printf "Docker cache layer matching is disabled (--no-cache)\n"
    docker_opts+=(--no-cache)
fi

docker_opts+=(
    --build-arg BUILDDATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    --build-arg BUILDNODE="$CURRENT_HOST"
    --build-arg SOURCE_COMMIT="$SOURCE_COMMIT"
    --build-arg SOURCE_URL="$SOURCE_URL"
)

for target_tag in "${DOCKER_TAGS[@]}"; do
    docker_opts+=(-t "$target_tag")
done

if $delta_updates; then
    printf "This build does not support delta-updates. Building full image.\n"
fi

docker build . "${docker_opts[@]}" -f "$DOCKERFILE_PATH" --rm


#
# Run tests for the Docker image unless skipped
#
printf "## Running Tests\n\n"

if ! $skip_tests; then
    if [ -f "$TEST_SCRIPT_PATH" ]; then
        bash "$TEST_SCRIPT_PATH" "${DOCKER_TAGS[0]}" "${DOCKER_TEST_COMMAND[@]}"
    else
        printf "ERROR: Test script expected at %s but not found.\n" "$TEST_SCRIPT_PATH" >&2
        exit 1
    fi
else
    printf "Skipping tests.\n"
fi


#
# Push the Docker image to all configured tags unless skipped
#
printf "## Pushing Docker Tags\n\n"

if ! $skip_push; then
    for target_tag in "${DOCKER_TAGS[@]}"; do
        printf "Pushing %s...\n" "$target_tag"
        docker push "$target_tag"
    done
else
    printf "Skipping push operations\n"
fi

printf "**Job's Done**\n\n"
