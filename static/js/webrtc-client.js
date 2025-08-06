/**
 * StreamLite WebRTC Client
 * Handles WebRTC peer connections for broadcasting and viewing streams
 */

// Global variables
let peerConnection;
let dataChannel;
let localStream;
let socket;
let statsInterval;
let isBroadcaster = false;
let currentStreamKey = '';

// STUN servers for ICE candidates
const configuration = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
        { urls: 'stun:stun2.l.google.com:19302' },
    ]
};

/**
 * Initialize WebRTC connection as broadcaster or viewer
 * @param {boolean} broadcaster - Whether this client is a broadcaster or viewer
 * @param {string} streamKey - The stream key to use
 */
async function initWebRTC(broadcaster = false, streamKey = '') {
    isBroadcaster = broadcaster;
    
    if (!streamKey && isBroadcaster) {
        // Get stream key from input field for broadcasters
        streamKey = document.getElementById('streamKey').value.trim();
    }
    
    currentStreamKey = streamKey;
    
    // Setup Socket.IO for real-time chat
    setupSocketIO(streamKey);
    
    // Set up event listeners
    if (isBroadcaster) {
        setupBroadcasterUI();
    } else {
        setupViewerUI();
    }
}

/**
 * Set up Socket.IO connection for chat
 * @param {string} streamKey - The stream key for the room
 */
function setupSocketIO(streamKey) {
    // Always use secure WebSocket connection on port 5443
    // Use dedicated WebRTC server URL instead of current page host
    const socketUrl = 'wss://hwosecurity.org:5443';
    
    socket = io(socketUrl);
    
    socket.on('connect', () => {
        console.log('Socket.IO connected');
        
        // Join the room based on stream key
        if (streamKey) {
            socket.emit('join_room', { stream_key: streamKey });
        }
    });
    
    socket.on('disconnect', () => {
        console.log('Socket.IO disconnected');
    });
    
    socket.on('user_joined', (data) => {
        console.log('User joined, total viewers:', data.count);
        if (document.getElementById('viewersCount')) {
            document.getElementById('viewersCount').textContent = `${data.count} viewers`;
        }
    });
    
    socket.on('user_left', (data) => {
        console.log('User left, total viewers:', data.count);
        if (document.getElementById('viewersCount')) {
            document.getElementById('viewersCount').textContent = `${data.count} viewers`;
        }
    });
    
    socket.on('new_chat', (data) => {
        console.log('New chat message:', data);
        if (window.addChatMessage) {
            window.addChatMessage(data.username, data.message, data.timestamp);
        }
    });
    
    window.socket = socket;
}

/**
 * Set up UI events for broadcaster
 */
function setupBroadcasterUI() {
    const startButton = document.getElementById('startButton');
    const stopButton = document.getElementById('stopButton');
    const toggleAudioButton = document.getElementById('toggleAudioButton');
    const toggleVideoButton = document.getElementById('toggleVideoButton');
    
    if (startButton) {
        startButton.addEventListener('click', startBroadcasting);
    }
    
    if (stopButton) {
        stopButton.addEventListener('click', stopBroadcasting);
    }
    
    if (toggleAudioButton) {
        toggleAudioButton.addEventListener('click', () => {
            if (localStream) {
                const audioTracks = localStream.getAudioTracks();
                if (audioTracks.length > 0) {
                    const enabled = !audioTracks[0].enabled;
                    audioTracks[0].enabled = enabled;
                    toggleAudioButton.textContent = enabled ? 'Mute Audio' : 'Unmute Audio';
                }
            }
        });
    }
    
    if (toggleVideoButton) {
        toggleVideoButton.addEventListener('click', () => {
            if (localStream) {
                const videoTracks = localStream.getVideoTracks();
                if (videoTracks.length > 0) {
                    const enabled = !videoTracks[0].enabled;
                    videoTracks[0].enabled = enabled;
                    toggleVideoButton.textContent = enabled ? 'Disable Video' : 'Enable Video';
                }
            }
        });
    }
}

/**
 * Set up UI events for viewer
 */
function setupViewerUI() {
    if (currentStreamKey) {
        startViewing(currentStreamKey);
    }
}

/**
 * Start broadcasting a stream
 */
async function startBroadcasting() {
    const streamKey = document.getElementById('streamKey').value.trim();
    if (!streamKey) {
        alert('Please enter a stream key');
        return;
    }
    
    currentStreamKey = streamKey;
    
    try {
        // Get user media
        localStream = await navigator.mediaDevices.getUserMedia({
            audio: true,
            video: {
                width: { ideal: 1280 },
                height: { ideal: 720 },
                frameRate: { ideal: 30 }
            }
        });
        
        // Display local video
        const localVideo = document.getElementById('localVideo');
        if (localVideo) {
            localVideo.srcObject = localStream;
        }
        
        // Create peer connection
        createPeerConnection(true);
        
        // Add tracks
        localStream.getTracks().forEach(track => {
            peerConnection.addTrack(track, localStream);
        });
        
        // Create offer
        const offer = await peerConnection.createOffer();
        await peerConnection.setLocalDescription(offer);
        
        // Send offer to server (use absolute URL to WebRTC server)
        const response = await fetch('https://hwosecurity.org:5443/webrtc/offer', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                sdp: peerConnection.localDescription.sdp,
                type: peerConnection.localDescription.type,
                streamKey: streamKey,
                broadcaster: true
            })
        });
        
        const answer = await response.json();
        await peerConnection.setRemoteDescription(new RTCSessionDescription(answer));
        
        // Update UI
        document.getElementById('startButton').disabled = true;
        document.getElementById('stopButton').disabled = false;
        document.getElementById('streamStatus').classList.add('status-live');
        document.getElementById('streamStatus').textContent = 'LIVE';
        document.getElementById('connectionStatus').textContent = 'Broadcasting';
        
        // Update share URL (use absolute URL to hwosecurity.org)
        const shareUrl = `https://hwosecurity.org:5443/webrtc/view/${streamKey}`;
        document.getElementById('shareUrl').textContent = shareUrl;
        document.getElementById('shareUrl').href = shareUrl;
        
        // Show video resolution
        const videoTrack = localStream.getVideoTracks()[0];
        if (videoTrack) {
            const settings = videoTrack.getSettings();
            document.getElementById('videoResolution').textContent = `${settings.width}x${settings.height}`;
        }
        
        // Set up stats monitoring
        startStatsMonitoring();
        
    } catch (error) {
        console.error('Error starting broadcast:', error);
        alert(`Error starting broadcast: ${error.message}`);
    }
}

/**
 * Stop broadcasting
 */
function stopBroadcasting() {
    // Stop all tracks
    if (localStream) {
        localStream.getTracks().forEach(track => track.stop());
    }
    
    // Clean up peer connection
    if (peerConnection) {
        peerConnection.close();
    }
    
    // Reset UI
    document.getElementById('startButton').disabled = false;
    document.getElementById('stopButton').disabled = true;
    document.getElementById('streamStatus').classList.remove('status-live');
    document.getElementById('streamStatus').textContent = 'Offline';
    document.getElementById('connectionStatus').textContent = 'Not connected';
    document.getElementById('videoResolution').textContent = '-';
    document.getElementById('bitrate').textContent = '-';
    
    // Clear video element
    const localVideo = document.getElementById('localVideo');
    if (localVideo) {
        localVideo.srcObject = null;
    }
    
    // Stop stats monitoring
    if (statsInterval) {
        clearInterval(statsInterval);
    }
    
    // Leave room
    if (socket && currentStreamKey) {
        socket.emit('leave_room', { stream_key: currentStreamKey });
    }
}

/**
 * Start viewing a stream
 * @param {string} streamKey - The stream key to view
 */
async function startViewing(streamKey) {
    try {
        // Create peer connection
        createPeerConnection(false);
        
        // Create offer (empty in viewer mode)
        const offer = await peerConnection.createOffer({
            offerToReceiveAudio: true,
            offerToReceiveVideo: true
        });
        await peerConnection.setLocalDescription(offer);
        
        // Send offer to server (use absolute URL to WebRTC server)
        const response = await fetch('https://hwosecurity.org:5443/webrtc/offer', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                sdp: peerConnection.localDescription.sdp,
                type: peerConnection.localDescription.type,
                streamKey: streamKey,
                broadcaster: false
            })
        });
        
        const answer = await response.json();
        await peerConnection.setRemoteDescription(new RTCSessionDescription(answer));
        
    } catch (error) {
        console.error('Error starting viewer:', error);
        const loadingOverlay = document.getElementById('loadingOverlay');
        if (loadingOverlay) {
            const errorMsg = document.createElement('div');
            errorMsg.className = 'alert alert-danger mt-3';
            errorMsg.innerHTML = `<strong>Error:</strong> ${error.message}<br>The stream may not be active.`;
            loadingOverlay.appendChild(errorMsg);
        }
    }
}

/**
 * Create RTCPeerConnection
 * @param {boolean} isBroadcaster - Whether this is a broadcaster connection
 */
function createPeerConnection(isBroadcaster) {
    // Close existing connection if any
    if (peerConnection) {
        peerConnection.close();
    }
    
    // Create new connection
    peerConnection = new RTCPeerConnection(configuration);
    
    // Handle ICE candidates
    peerConnection.onicecandidate = event => {
        if (event.candidate) {
            console.log('ICE candidate:', event.candidate);
        }
    };
    
    // Handle connection state changes
    peerConnection.onconnectionstatechange = () => {
        console.log('Connection state:', peerConnection.connectionState);
        if (document.getElementById('connectionStatus')) {
            document.getElementById('connectionStatus').textContent = peerConnection.connectionState;
        }
    };
    
    // Handle ice connection state changes
    peerConnection.oniceconnectionstatechange = () => {
        console.log('ICE connection state:', peerConnection.iceConnectionState);
    };
    
    // Handle track reception (for viewers)
    if (!isBroadcaster) {
        peerConnection.ontrack = event => {
            console.log('Received track:', event.track.kind);
            const remoteVideo = document.getElementById('remoteVideo');
            if (remoteVideo && event.streams && event.streams[0]) {
                remoteVideo.srcObject = event.streams[0];
            }
        };
    }
    
    return peerConnection;
}

/**
 * Start monitoring WebRTC stats
 */
function startStatsMonitoring() {
    if (statsInterval) {
        clearInterval(statsInterval);
    }
    
    let lastBytesSent = 0;
    let lastTimestamp = Date.now();
    
    statsInterval = setInterval(async () => {
        if (!peerConnection) return;
        
        try {
            const stats = await peerConnection.getStats();
            
            stats.forEach(report => {
                if (report.type === 'outbound-rtp' && report.kind === 'video') {
                    const bytesSent = report.bytesSent;
                    const timestamp = report.timestamp;
                    
                    if (lastBytesSent && lastTimestamp) {
                        const bitrate = 8 * (bytesSent - lastBytesSent) / (timestamp - lastTimestamp);
                        const bitrateKbps = Math.round(bitrate / 1000);
                        
                        if (document.getElementById('bitrate')) {
                            document.getElementById('bitrate').textContent = `${bitrateKbps} kbps`;
                        }
                    }
                    
                    lastBytesSent = bytesSent;
                    lastTimestamp = timestamp;
                }
            });
        } catch (error) {
            console.error('Error getting stats:', error);
        }
    }, 1000);
}

// Export for use in HTML
window.initWebRTC = initWebRTC;
window.startBroadcasting = startBroadcasting;
window.stopBroadcasting = stopBroadcasting;
window.startViewing = startViewing;