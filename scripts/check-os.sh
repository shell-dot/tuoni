#!/bin/bash

set -e

# Check if the operating system is supported
if ! grep -q -E "ID=(kali|debian|ubuntu)" /etc/os-release; then
  echo "ERROR | Operating system not supported, please use Kali/Debian/Ubuntu";
  exit 1;
fi
