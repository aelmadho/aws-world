#!/bin/bash

ssh-keygen -t rsa -b 4096 -f "api" -N "" -C "aws_ssh_key"
