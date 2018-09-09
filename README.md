# 7 Days to Die Dedicated Server in Docker

7 Days to Die is a survival horror video game set in an open world.  Players are survivors of World War  3 that destroyed an extremely large part of the world, except for some areas such as the fictional county of Navezgane, Arizona. Players must survive by finding shelter, food and water, as well as scavenging supplies to fend off the numerous zombies (hinted to be the consequence of nuclear fallout) that populate Navezgane. Player interactions can be cooperative or hostile depending on the used server options - there are two supported game modes for multiplayer: Survival (both randomly generated and standard) and Creative.

![7 Days to Die Box Art](https://raw.githubusercontent.com/LacledesLAN/gamesvr-7daystodie/master/.misc/boxart.jpg "7 Days to Die Box Art")

This repository is maintained by [Laclede's LAN](https://lacledeslan.com). Its contents are intended to be bare-bones and used as a stock server. For examples of building a customized server from this Docker image browse its related child-project [gamesvr-7daystodie-freeplay](https://github.com/LacledesLAN/gamesvr-7daystodie-freeplay). If any documentation is unclear or it has any issues please see [CONTRIBUTING.md](./CONTRIBUTING.md).

# Linux Container
[![](https://images.microbadger.com/badges/version/lacledeslan/gamesvr-7daystodie.svg)](https://microbadger.com/images/lacledeslan/gamesvr-7daystodie "Get your own version badge on microbadger.com")
[![](https://images.microbadger.com/badges/image/lacledeslan/gamesvr-7daystodie.svg)](https://microbadger.com/images/lacledeslan/gamesvr-7daystodie "Get your own image badge on microbadger.com")

## Download
```shell
docker pull lacledeslan/gamesvr-7daystodie
```

## Run Interactive Server
```shell
docker run -it --rm --net=host lacledeslan/gamesvr-7daystodie ./startserver.sh -configfile=serverconfig.xml
```

## Getting Started with Game Servers in Docker

[Docker](https://docs.docker.com/) is an open-source project that bundles applications into lightweight, portable, self-sufficient containers. For a crash course on running Dockerized game servers check out [Using Docker for Game Servers](https://github.com/LacledesLAN/README.1ST/blob/master/GameServers/DockerAndGameServers.md). For tips, tricks, and recommended tools for working with Laclede's LAN Dockerized game server repos see the guide for [Working with our Game Server Repos](https://github.com/LacledesLAN/README.1ST/blob/master/GameServers/WorkingWithOurRepos.md). You can also browse all of our other Dockerized game servers: [Laclede's LAN Game Servers Directory](https://github.com/LacledesLAN/README.1ST/tree/master/GameServers).
