---
name: aichat
description: All-in-one LLM CLI tool for sending prompts, switching models, piping stdin, including files, and using roles/sessions. Use as an AI adapter for shell workflows.
metadata:
  short-description: LLM CLI tool for prompts, models, and shell pipelines
---

# aichat

aichat is an all-in-one LLM CLI tool. Use it to send prompts to any configured model, pipe text through LLMs, or integrate AI into shell workflows.

Binary: `/home/kundeng/.local/bin/aichat`
Config: `~/.config/aichat/config.yaml`

## Basic usage

```bash
aichat "summarize the key points"          # one-shot prompt
aichat -m openai:gpt-4o "explain X"       # pick a specific model
echo "some text" | aichat "summarize this" # pipe stdin as context
cat log.txt | aichat "find errors"         # filter/analyze files via pipe
aichat -f README.md "summarize this file"  # include a file directly
aichat -f src/ "review this code"          # include a whole directory
```

## Key flags

| Flag | Purpose |
|------|---------|
| `-m MODEL` | Select model (provider:model format) |
| `-S` | Disable streaming (wait for full response) |
| `-c` | Output code only (no explanation) |
| `-f FILE` | Include file, directory, or URL as context |
| `-r ROLE` | Use a predefined role |
| `-s [NAME]` | Start or join a named session (conversation memory) |
| `-e` | Execute mode: generate and run shell commands |
| `--prompt TEXT` | Set a system prompt |
| `--dry-run` | Show the message without sending |

## Discovery commands

```bash
aichat --list-models      # list all available chat models
aichat --list-roles       # list configured roles
aichat --list-sessions    # list saved sessions
aichat --list-agents      # list available agents
aichat --info             # show current config and model info
aichat --sync-models      # refresh model list from providers
```

## Using as an AI adapter

aichat works as a stdin/stdout AI adapter for other tools:

```bash
git diff | aichat "write a commit message"
curl -s https://example.com | aichat "extract the main content"
cat data.csv | aichat -c "python script to plot column 2 vs 3"
```

Use `-S` (no-stream) when capturing output programmatically so you get the complete response at once.

## Agents and RAG

```bash
aichat -a myagent "do the task"                        # run an agent
aichat --rag myrag "search query"                      # query a RAG
aichat --agent-variable NAME VALUE -a myagent "prompt" # pass variables to agent
```
