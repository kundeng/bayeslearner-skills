# Splunk JavaScript SDK Reference

Use this for:

- Node services that talk to Splunk
- JS/TS services in an existing Node stack
- legacy SplunkJS/Web Framework code inside Splunk apps
- rare browser-side integrations where client execution is intentional

## Default Choice

Prefer Python unless there is a clear Node/JS reason to stay in JavaScript.

Use the JS SDK when:

- the surrounding service is already Node/TS
- you are extending existing SplunkJS-based app code
- shared JS runtime or package reuse matters

## Install

```bash
npm install splunk-sdk
```

## Server-Side First

Default to server-side Node code. That keeps credentials off the browser and
makes search execution, retries, and result shaping easier to control.

Browser-side use is legacy-friendly but should be the exception, not the
default.

## Good Fits

- Node integration service
- existing Express/Fastify/Nest backend that needs Splunk access
- legacy SplunkJS app extension
- small admin tools in a JS-heavy repo

## Poor Fits

- large exports and notebook pipelines
- new greenfield automation with no JS dependency
- agent backends that need the simplest possible operational story

For those, prefer Python.

## Common Patterns

### Connect and login

```javascript
const splunkjs = require("splunk-sdk");

const service = new splunkjs.Service({
  scheme: "https",
  host: "splunk.example.com",
  port: 8089,
  username: process.env.SPLUNK_USER,
  password: process.env.SPLUNK_PASSWORD,
});

await service.login();
```

### Fetch jobs

```javascript
const jobs = await service.jobs().fetch();
const list = jobs.list();
```

### Update config stanzas

The JS SDK can work with configuration files and stanzas. Use this only in
trusted admin/app contexts, not general-purpose user-driven flows.

## Search Guidance

- Treat JS SDK jobs the same way you treat Python SDK jobs: `oneshot` only for small bounded results.
- Use managed jobs for moderate workloads.
- Fall back to raw REST when you need streaming export semantics.
- Keep search strings explicit and time-bounded.

## Browser Caveats

- Avoid long-lived credentials in browser code.
- Prefer server proxy patterns for auth and query enforcement.
- Use browser components only when you truly need client-side visualization or token-driven interactions in legacy SplunkJS contexts.

## Legacy UI Context

The JS SDK still matters for SplunkJS Stack and older custom UI patterns, but
do not treat that as the preferred path for new dashboards. New dashboards
should normally be Dashboard Studio; legacy Simple XML and SplunkJS work should
be maintained rather than expanded.

## Sources

- https://github.com/splunk/splunk-sdk-javascript
