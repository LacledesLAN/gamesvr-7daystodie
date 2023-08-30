#!/bin/bash
set -e;
set -u;


####################################################################################################
## Options
####################################################################################################

# Default options
option_delta_updates=false;	# Only build delta layer at the base image level?

# Parse command line options
while [ "$#" -gt 0 ]
do
	case "$1" in
		# unknown
		*)
			echo "Error: unknown option '${1}'. Exiting." >&2;
			exit 12;
			;;
	esac
	shift
done;


####################################################################################################
## Helper Functions
####################################################################################################

# Custom sigterm handler, so that interupt signals terminate the script, not just a single command.
sigterm_handler() {
	echo -e "\n";
	exit 1;
}

trap 'trap " " SIGINT SIGTERM SIGHUP; kill 0; wait; sigterm_handler' SIGINT SIGTERM SIGHUP;


####################################################################################################
## Build
####################################################################################################


echo -e '\n\033[1m[Build Full Image]\033[0m';
docker build . -f linux.Dockerfile --rm -t lacledeslan/gamesvr-7daystodie:latest --no-cache --pull --build-arg BUILDNODE="$(cat /proc/sys/kernel/hostname)";


#echo -e '\n\033[1m[Running Image Self-Checks]\033[0m';
echo -e "no self checks to run";


echo -e '\n\033[1m[Pushing to Docker Hub]\033[0m';

echo "> push lacledeslan/gamesvr-7daystodie:latest"
docker push lacledeslan/gamesvr-7daystodie:latest
