# CaptivePortal
A wrapper for [linux-router](https://github.com/garywill/linux-router/) to make a captive portal.

## Features ##

* PHP web server captive portal
* Abilty to see mac address of IP
* Uses [trafex/php-nginx](https://hub.docker.com/r/trafex/php-nginx) container to host the web server

## How to run ##
* Make the necessary changes in the global variables of `captive`
* Put your captive portal web server PHP code in `site/`
* `sudo ./captive`

## Issues ##
* Since the docker container is running on the host network, it can lead to security issues, especially if the php code in `site/` is vulnerable to exploits.
* If the `captive.sh` script crashes, it will not do a proper clean up, you may need to manually remove the docker container as well as remove the iptables rule.
