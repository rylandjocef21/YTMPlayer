# Pull Request Template

Please use this template when opening a pull request.

## Summary
Provide a one-paragraph description of the change and why it's needed.

## Changes
- List the main files changed and what they do.

## How to test
- Build: export THEOS=/path/to/theos && make package
- Install .deb on a test iOS 9/10 device and verify functionality (search, play, background playback)

## Checklist
- [ ] I have updated YTMConfig.h with any required configuration or documented that it should be configured by the reviewer
- [ ] Code is split into logical modules with single responsibility
- [ ] Network errors are handled (no crashes on malformed responses)
- [ ] Added/updated README or documentation if behavior changed
- [ ] Manual tested: search -> select -> playback works for direct URLs
- [ ] Added tests where applicable (e.g., parser unit tests)

## Notes
- The client intentionally does not implement YouTube signature deciphering. If the PR introduces changes that require deciphering, include instructions to use a proxy (yt-dlp/yt-dlp-server/Invidious-like) and how to configure YTMConfig.h.
- Mention any legal/ToS concerns if the change affects content extraction behavior.
