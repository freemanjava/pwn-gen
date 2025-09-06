#!/bin/bash -e
echo -e "\e[32m### Configuring touch interface ###\e[0m"
# Enable any required services for touch interface
systemctl enable pwnagotchi-touch
