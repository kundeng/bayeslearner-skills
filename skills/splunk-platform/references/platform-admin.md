# Splunk Platform Administration

Use this for:
- deploying or upgrading Splunk infrastructure
- admin automation
- platform configuration patterns outside app code

## Scope

This is about Splunk hosts and deployments, not SPL authoring.

Typical concerns:
- install/upgrade automation
- role-specific deployment patterns
- app/add-on rollout
- OS tuning and service configuration
- distributed search and clustered role awareness

## Current Official-ish Automation References

- `splunk/ansible-role-for-splunk` for managing remote Splunk hosts
- `splunk/splunk-platform-automator` for spinning up larger Splunk environments

## Strong Defaults

- Prefer official Splunk automation repositories before custom shell scripts.
- Treat role topology explicitly: standalone, search head, indexer, cluster manager, deployer, deployment server.
- Keep app rollout separate from host bootstrap where practical.
- Avoid ad hoc mutable snowflake hosts.

## Common Use Cases

- install or upgrade Splunk Enterprise on fleets of hosts
- configure clustered/distributed roles
- deploy apps and add-ons consistently
- bootstrap labs or test environments
- codify service configuration and OS prerequisites

## Notes

- The official Ansible role covers installation, upgrades, app deployment, and configuration across Splunk deployment roles.
- `splunk-platform-automator` is more useful for environment creation and reference topology than for everyday app code tasks.
- Use this reference only when the task is platform administration rather than data analysis or app code.

## What This Is Not

- not a substitute for SPL discovery
- not a substitute for app packaging/UCC
- not the right place to solve export/SDK questions

Route those tasks back to the appropriate references.

## Sources

- https://github.com/splunk/ansible-role-for-splunk
- https://github.com/splunk/splunk-platform-automator
