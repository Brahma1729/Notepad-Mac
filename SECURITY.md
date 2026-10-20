# Security policy

Security fixes target the latest code on `main`. Update to the latest version before reporting a problem.

## Report a vulnerability privately

Use [GitHub private vulnerability reporting](https://github.com/kiranrbharadwaj/Notepad-Mac/security/advisories/new). Do not include exploit details, credentials, private documents, or personal information in public issues or pull requests. If private reporting is unavailable, contact the maintainer through their GitHub profile to arrange a private channel before sharing details.

Include the affected commit or version, macOS version, reproduction steps using a minimal synthetic file, expected impact, and any proposed fix. No response-time guarantee is offered.

## Scope

The app opens and writes local text files with your user account's permissions. It is not a sandbox for untrusted content. The app declares no third-party package dependencies. Locally built app bundles use ad-hoc signing; they are not notarized releases. Never commit credentials, signing keys, private documents, or generated app bundles.
