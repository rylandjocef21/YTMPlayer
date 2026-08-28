# YTMPlayer (refactor/modular-player)

This branch refactors the app into modular components:
- YTMNetworkClient: InnerTube calls (search/player)
- YTMTrackParser: JSON -> track objects
- YTMPlayerManager: AVPlayer + remote control

Configuration:
- Edit YTMConfig.h to set YTMInnerTubeApiKey or set YTMProxyBaseURL to your proxy that resolves stream URLs (recommended).
- Running against YouTube directly from the client may fail for streams requiring signature deciphering. Use a small backend (yt-dlp/yt-server/invidious-like) to return ready-to-play URLs.

Build:
- Requires Theos.
- From repo root: export THEOS=/opt/theos (adjust) then make package
- Install on jailbroken device with dpkg -i packages/*.deb and run uicache.

Legal:
- Using YouTube endpoints for extraction/streaming outside YouTube's rules can violate ToS and copyright law. Use for private research only.
