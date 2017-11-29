# 7 Days to Die Server in Docker

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
