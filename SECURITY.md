# Security policy

## Reporting a vulnerability

Report it through OpenSea's Bugcrowd program:

**https://bugcrowd.com/engagements/opensea**

That is the channel OpenSea's security team monitors, and it is where a report gets triaged and tracked. Please do not open a public GitHub issue, discussion, or pull request describing a vulnerability, and please hold off on public disclosure until the program has responded.

The Bugcrowd brief is the authority on what is in scope, what is excluded, how severity is assessed, and how rewards work. This file deliberately does not restate any of that, because a second copy would drift out of date and contradict the brief. Read the brief before you start.

Response and disclosure timelines are set by the program, not by this repository.

## About this repository

`@opensea/skill` ships agent skill files: instructions, reference docs, and helper shell scripts that an AI agent loads in order to work with OpenSea. There is no hosted service in this repository.

The surface is content that steers an agent and the scripts that ship alongside it. Instructions that can be turned against the agent that loads them, and anything unsafe in the bundled scripts, are the parts worth looking at.

This repository is a read-only mirror published from a private OpenSea monorepo. A fix lands here as a synced commit rather than as a merged pull request, so do not read the absence of a PR as the absence of a fix.

## Please do not

- Test against production. Do not run exploit attempts against opensea.io, api.opensea.io, or any other OpenSea-operated service. Reproduce against a local build, a testnet, or your own deployment.
- Run automated scanners, fuzzers, or crawlers against opensea.io or the OpenSea API. That traffic is indistinguishable from an attack, it gets blocked, and raw scanner output on its own is not a report.
- Touch accounts, wallets, or data that are not yours. Use your own.
- Attempt denial of service, spam, or social engineering against OpenSea staff, users, or infrastructure.

We cannot accept a finding that required breaking one of these to produce, however real the underlying bug is.
