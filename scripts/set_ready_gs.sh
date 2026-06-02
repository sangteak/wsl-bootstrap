#!/bin/bash

declare -a servers

# kubectl 명령어 결과를 배열로 저장
while IFS= read -r line; do
    servers+=("$line")
done < <(kubectl get gs | grep Allocated | awk '{print $3, $4}')

for server in "${servers[@]}"; do
	ip=$(echo $server | awk '{print $1}')
	port=$(echo $server | awk '{print $2}')

	echo "EXIT" | timeout 1 nc -u $ip $port
done

