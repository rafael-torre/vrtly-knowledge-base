Are ads streamed live or loaded beforehand? Playlist is generated server-side daily and pushed to the device. Content is cached locally and served via HLS over CloudFront. The device plays from cache — not a live stream.

Poor/no internet handling? Playback continues from local cache. There's a watchdog that escalates through skip → reset playlist → full app reset if playback stalls. Reconnects to WebSocket at 1s intervals. No graceful degradation beyond that today.

Which devices/locations complain most? We don't have clean data on this — no proactive alerting, so complaints are inbound only. Anecdotally older Android hardware and Samsung TVs on certain model groups are the most problematic.

How do clients report problems? They call or email CS. No self-service portal for device issues. CS has a telemetry dashboard but it's incomplete and hard to use, so most issues escalate to engineering.

Vrtly's responsibility to fix remotely?Yes, fully remote. Practices are cooperative — they turn TVs on daily and will walk through issues with us — but there's no on-site tech. All fixes are pushed remotely.

Typical client profile? Small independent medical aesthetic practices — med spas, dermatology, plastic surgery. \~2,000 today. Not hospital chains. Some multi-location groups but mostly single-location owner-operators.

Screens deployed and growing? 3,000+ active connected screens. Growing, but the focus right now is reliability before scale

