#!/usr/bin/env bash
docker rmi sangtakeg/mm101-tutorial-matchfunction:latest
docker rmi sangtakeg/mm101-tutorial-director:latest
docker rmi sangtakeg/mm101-tutorial-frontend:latest

docker image ls
