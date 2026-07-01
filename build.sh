#!/bin/bash
set -euo pipefail

#######################################################################################################################
#######################################################################################################################
dockerfile_path='linux.Dockerfile'
docker_test_command=(/app/startserver.sh -configfile=serverconfig.xml)

# All tags in this array will be applied simultaneously during `docker build`.
docker_tags=(
    'lacledeslan/gamesvr-7daystodie:latest'
)
#######################################################################################################################
#######################################################################################################################

# Ensure docker_tags is defined and not empty immediately to satisfy set -u safely
if [ ${#docker_tags[@]} -eq 0 ]; then
    printf "ERROR: No docker_tags have been defined. Please specify at least one tag.\n" >&2
    exit 1
fi

#
# PREFLIGHT
#
SOURCE_COMMIT="unspecified"
CURRENT_HOST=$(hostname 2>/dev/null || echo "unknown-host")

if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
    SOURCE_COMMIT=$(git rev-parse --short HEAD)$([ -n "$(git status --porcelain)" ] && echo "-dirty")
    printf "# Building %s from \`%s\` on %s\n" "${docker_tags[0]}" "$SOURCE_COMMIT" "$CURRENT_HOST"
else
    printf "# Building %s on %s\n" "${docker_tags[0]}" "$CURRENT_HOST"
fi

# Verify docker command-line tool exists
if ! command -v docker &> /dev/null; then
    printf "ERROR: Docker is not installed or not in your PATH.\n" >&2
    exit 1
fi

if ! docker info &> /dev/null; then
    printf "ERROR: Docker is installed, but the current user cannot access the Docker daemon.\n" >&2
    exit 1
fi


#
# Parse command line options
#
option_enable_steamcmd_cache=false
option_skip_pull=false
option_skip_tests=false
option_skip_push=false
option_delete_built_image=false

while [ "$#" -gt 0 ]
do
    case "$1" in
        --enable-steamcmd-cache)
            option_enable_steamcmd_cache=true
            ;;
        --skip-pull)
            option_skip_pull=true
            ;;
        --skip-tests)
            option_skip_tests=true
            ;;
        --skip-push-dockerhub|--skip-push)
            option_skip_push=true
            ;;
        --delete-built-image)
            option_delete_built_image=true
            ;;
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
if [ "$option_delete_built_image" = 'true' ] && [ "$option_skip_push" = 'true' ]; then
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

    # Clean up dangling images safely without relying heavily on non-portable xargs flags
    local dangling_images
    dangling_images=$(docker images -q --filter "label=org.opencontainers.image.source=https://github.com/LacledesLAN/gamesvr-7daystodie" --filter "dangling=true")
    if [ -n "$dangling_images" ]; then
        echo "$dangling_images" | xargs docker rmi
    fi

    # Conditionally delete the built/tagged images if opt-in flag was provided
    if [ "$option_delete_built_image" = 'true' ]; then
        for target_tag in "${docker_tags[@]}"; do
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

if [ "$option_skip_pull" != 'true' ]; then
    docker_opts+=(--pull)
else
    printf "Skipping pulling the latest base image\n"
fi

if [ "$option_enable_steamcmd_cache" = 'true' ]; then
    printf "local SteamCMD cache is enabled\n"
    docker_opts+=(--build-arg ENABLE_STEAMCMD_CACHE="true")
fi

docker_opts+=(
    --build-arg BUILDDATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    --build-arg BUILDNODE="$CURRENT_HOST"
    --build-arg SOURCE_COMMIT="$SOURCE_COMMIT"
)

for target_tag in "${docker_tags[@]}"; do
    docker_opts+=(-t "$target_tag")
done

docker build . "${docker_opts[@]}" -f "$dockerfile_path" --rm


#
# Run tests for the Docker image unless skipped
#
printf "## Running Tests\n\n"

if [ "$option_skip_tests" != 'true' ]; then
    bash ./tests/test-gamesvr-7daystodie.sh "${docker_tags[0]}" "${docker_test_command[@]}"
else
    printf "Skipping tests.\n"
fi


#
# Push the Docker image to all configured tags unless skipped
#
printf "## Pushing Docker Tags\n\n"

if [ "$option_skip_push" != 'true' ]; then
    for target_tag in "${docker_tags[@]}"; do
        printf "Pushing %s...\n" "$target_tag"
        docker push "$target_tag"
    done
else
    printf "Skipping push operations\n"
fi

printf "**Job's Done**\n\n"
