# StreamLite - Streaming Platform

A robust streaming platform that provides advanced diagnostics, troubleshooting, and management tools for seamless media deployment across diverse hosting environments.

## Features

- **Multi-Protocol Streaming**: Support for both RTMP/HLS and WebRTC streaming protocols
- **User Management**: Registration, authentication, and profile management
- **Content Organization**: Categories and tags for media items
- **Interactive Features**: Live chat, viewer count, and stream analytics
- **Embedded Streaming**: Embeddable players for third-party websites
- **Mobile Compatibility**: Responsive design for mobile devices
- **Customizable Interface**: Theme and branding options
- **Advanced Diagnostics**: Comprehensive error logging and troubleshooting tools

## Streaming Protocols

### RTMP/HLS Streaming

StreamLite supports RTMP (Real-Time Messaging Protocol) for ingestion and HLS (HTTP Live Streaming) for playback:

- **Low-Latency Delivery**: Typical latency of 2-5 seconds
- **Wide Compatibility**: Works with OBS Studio, Streamlabs, XSplit, and other broadcasting software
- **Adaptive Bitrate**: Multiple quality levels for different network conditions
- **DVR Features**: Pause, rewind, and time-shifting capabilities
- **Cross-Platform Playback**: Works on desktop and mobile browsers

### WebRTC Streaming (Low Latency)

For ultra-low latency applications, StreamLite includes WebRTC streaming:

- **Ultra-Low Latency**: Typical latency of 200-500ms
- **Browser-Based Broadcasting**: Stream directly from your browser without additional software
- **Peer-to-Peer Capabilities**: Efficient data transfer between peers
- **Real-Time Interaction**: Ideal for interactive applications
- **Device Access**: Easy access to cameras and microphones

## Technical Architecture

- **Backend**: Flask-based Python application with SQLAlchemy ORM
- **Frontend**: Bootstrap 5 with responsive design and dark mode
- **Database**: PostgreSQL (or MySQL) for data storage
- **Media Processing**: FFmpeg for video transcoding and thumbnail generation
- **HLS Delivery**: Nginx with RTMP module for streaming
- **WebRTC**: aiortc, aiohttp, and python-socketio for low-latency streaming

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

For quick deployment on shared hosting, see [QUICK_DEPLOY.md](QUICK_DEPLOY.md).

## Troubleshooting

If you encounter issues, refer to the following guides:

- [RTMP Troubleshooting](RTMP_TROUBLESHOOTING.md)
- [WebRTC Troubleshooting](WEBRTC_TROUBLESHOOTING.md)
- [General Troubleshooting](TROUBLESHOOTING.md)

## Demo Site

The demo site is available at [https://hwosecurity.org](https://hwosecurity.org).

- RTMP/HLS Streaming: Standard port 1935 for RTMP input, web playback via HLS
- WebRTC Streaming: Available at [https://hwosecurity.org:5443/webrtc](https://hwosecurity.org:5443/webrtc)

## License

This project is open-source software, available under the MIT License.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.