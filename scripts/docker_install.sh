#!/usr/bin/env bash
docker build -t docker.io/sangtakeg/mm101-tutorial-frontend frontend/
#docker build -t docker.io/sangtakeg/mm101-tutorial-director director/
docker build -t docker.io/sangtakeg/mm101-tutorial-matchfunction matchfunction/

docker push docker.io/sangtakeg/mm101-tutorial-frontend
#docker push docker.io/sangtakeg/mm101-tutorial-director
docker push docker.io/sangtakeg/mm101-tutorial-matchfunction

docker image ls
