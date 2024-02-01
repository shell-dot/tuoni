#!/bin/bash

set -e

if ! grep -q -E "ID=(kali|debian|ubuntu)" /etc/os-release; then
  echo "ERROR | Operating system not supported, please use Kali/Debian/Ubuntu";
  exit 1;
fi
