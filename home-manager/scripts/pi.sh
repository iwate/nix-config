#!/usr/bin/env bash

OR_API_KEY=$(op read op://Private/OpenRouter/credential)
EXA_API_KEY=$(op read op://Private/Exa/credential)

docker run --rm -it \
  -e OPENROUTER_API_KEY="$OR_API_KEY" \
  -e EXA_API_KEY="$EXA_API_KEY" \
  -v "$PWD:/workspace" \
  -v pi-agent-home:/root/.pi/agent \
  pi-sandbox