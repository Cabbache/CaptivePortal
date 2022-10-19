#!/bin/bash
set -e

function resolve(){
	IPv4=$(getent ahosts "$1" | head -n1 | awk '{print $1}')

	#https://stackoverflow.com/questions/13777387/check-for-ip-validity
	if [[ $IPv4 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "$IPv4"
		return 0
	else
		return 1
	fi
}

DOMAINS=(
	"connectivitycheck.gstatic.com"
	"clients3.google.com"
	"google.com"
)

for i in ${!DOMAINS[@]}
do
	DOMAIN="${DOMAINS[i]}"
	IPv4=$(resolve "$DOMAIN")
	DOMAINS[i]="$IPv4 $DOMAIN"
done

printf '' > domains.txt

for i in ${!DOMAINS[@]}
do
	printf "${DOMAINS[i]}\n" >> domains.txt
done
