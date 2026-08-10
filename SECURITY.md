# Security Policy

## Supported versions

LetterLoom is currently maintained from the default branch. There is no published long-term support matrix or separate stable release line yet, so security fixes should be reported against the latest commit or release available in this repository.

## Reporting a vulnerability

Please do not disclose exploitable vulnerability details in a normal public GitHub issue, discussion, pull request, or social post.

If GitHub Security Advisories are enabled for this repository, use a private advisory. If they are unavailable, contact the repository owner privately through a GitHub channel and share only the minimum information needed to establish a private conversation. Do not include secrets in a report.

A useful report includes:

- a concise description of the issue and affected component;
- the commit, release, or configuration where it was observed;
- reproducible steps or a minimal proof of concept, when safe to share;
- expected and observed behavior;
- impact and realistic prerequisites;
- logs, screenshots, or source locations that help verification; and
- any suggested mitigation.

Please allow maintainers reasonable time to verify the report, prepare a fix, and coordinate disclosure. Response and remediation timing depends on severity, reproducibility, and maintainer availability; no fixed response-time guarantee is made.

## Scope notes

Never commit Supabase secret/service-role keys, Firebase service-account JSON, signing keys, `dart_defines.json`, or other private configuration. The Flutter client must use only the intended public/publishable Supabase value.
