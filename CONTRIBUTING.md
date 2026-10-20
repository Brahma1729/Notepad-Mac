# Contributing

Open an issue for a bug or proposed improvement, then submit focused changes through a pull request against `main`. Security vulnerabilities should be reported privately as described in [SECURITY.md](SECURITY.md).

## Validate changes

On macOS with Swift 5.9 or later:

```sh
swift build
swift run NotepadMac --selftest
git diff --check
```

For interface changes, also check the app visually with empty documents, multiline text, wrapping, resizing, and scrolling as relevant. The existing self-tests cover search and encoding, not all interface behavior.

Submit original work or document compatible third-party licenses and required notices. By submitting a contribution, you agree that your contribution is provided under the repository's MIT license. Do not include secrets, private files, generated build output, or machine-specific assistant configuration.

`main` is protected against deletion and force pushes. Contributor pull requests require one approval; repository administrators can bypass the review rule, matching the maintainer's reference repository setup.
