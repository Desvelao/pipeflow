#!/bin/bash

luarocks install --only-deps /app/rockspec*.rockspec

tail -f /dev/null