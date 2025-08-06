import asyncio
import json
import os
import ssl
import time
import uuid
from pathlib import Path

import aiohttp
from aiohttp import web
import socketio
from aiortc import MediaStreamTrack, RTCPeerConnection, RTCSessionDescription
from aiortc.contrib.media import MediaBlackhole, MediaPlayer, MediaRelay, MediaRecorder

# Create a Socket.IO server
sio = socketio.AsyncServer(cors_allowed_origins='*', async_mode='aiohttp')
relay = MediaRelay()
pcs = set()
active_broadcasters = {}  # Maps stream keys to a list of tracks for broadcasting

# Get SSL context for secure WebRTC communication
def get_ssl_context():
    ssl_context = None
    cert_file = os.environ.get('SSL_CERT_FILE')
    key_file = os.environ.get('SSL_KEY_FILE')
    
    if cert_file and key_file and os.path.exists(cert_file) and os.path.exists(key_file):
        ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ssl_context.load_cert_chain(cert_file, key_file)
    else:
        print("SSL certificate files not found or not specified. Using insecure connection.")
    
    return ssl_context

# Define routes
async def index(request):
    content = open(os.path.join(os.path.dirname(__file__), 'templates/webrtc/index.html'), 'r').read()
    return web.Response(content_type='text/html', text=content)

async def javascript(request):
    content = open(os.path.join(os.path.dirname(__file__), 'static/js/webrtc-client.js'), 'r').read()
    return web.Response(content_type='application/javascript', text=content)

async def broadcast_page(request):
    """Page for broadcasters to stream using WebRTC"""
    content = open(os.path.join(os.path.dirname(__file__), 'templates/webrtc/broadcast.html'), 'r').read()
    return web.Response(content_type='text/html', text=content)

async def viewer_page(request):
    """Page for viewers to watch WebRTC streams"""
    content = open(os.path.join(os.path.dirname(__file__), 'templates/webrtc/viewer.html'), 'r').read()
    return web.Response(content_type='text/html', text=content)

async def offer(request):
    params = await request.json()
    offer = RTCSessionDescription(sdp=params["sdp"], type=params["type"])
    stream_key = params.get("streamKey")
    is_broadcaster = params.get("broadcaster", False)
    
    pc = RTCPeerConnection()
    pc_id = f"PeerConnection_{uuid.uuid4()}"
    pcs.add(pc)
    
    # For debugging
    print(f"Created peer connection: {pc_id}")
    print(f"Is broadcaster: {is_broadcaster}")
    print(f"Stream key: {stream_key}")
    
    if is_broadcaster and stream_key:
        @pc.on("track")
        def on_track(track):
            print(f"Track received from broadcaster: {track.kind}")
            if stream_key not in active_broadcasters:
                active_broadcasters[stream_key] = []
            
            # Relay the track and keep a reference
            relayed_track = relay.subscribe(track)
            active_broadcasters[stream_key].append(relayed_track)
            
            @track.on("ended")
            async def on_ended():
                print(f"Track ended for broadcaster: {track.kind}")
                if stream_key in active_broadcasters:
                    if relayed_track in active_broadcasters[stream_key]:
                        active_broadcasters[stream_key].remove(relayed_track)
                    
                    # If no tracks left, remove the broadcaster
                    if not active_broadcasters[stream_key]:
                        del active_broadcasters[stream_key]
    
    elif stream_key and stream_key in active_broadcasters:
        # This is a viewer, add tracks from the broadcaster
        for track in active_broadcasters[stream_key]:
            pc.addTrack(track)
            print(f"Added track to viewer: {track.kind}")
    else:
        if not is_broadcaster:
            print(f"Viewer tried to access non-existent stream: {stream_key}")
    
    @pc.on("iceconnectionstatechange")
    async def on_iceconnectionstatechange():
        print(f"ICE connection state changed to: {pc.iceConnectionState}")
        if pc.iceConnectionState == "failed" or pc.iceConnectionState == "closed":
            await pc.close()
            pcs.discard(pc)
    
    # Handle offer
    await pc.setRemoteDescription(offer)
    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    
    return web.Response(
        content_type="application/json",
        text=json.dumps({
            "sdp": pc.localDescription.sdp,
            "type": pc.localDescription.type
        })
    )

# Socket.IO events
@sio.event
async def connect(sid, environ):
    print(f"Client connected: {sid}")

@sio.event
async def disconnect(sid):
    print(f"Client disconnected: {sid}")

@sio.event
async def join_room(sid, data):
    room = data.get('stream_key')
    if room:
        sio.enter_room(sid, room)
        print(f"Client {sid} joined room {room}")
        # Notify others in room
        await sio.emit('user_joined', {'count': len(sio.rooms.get(room, {}))}, room=room)

@sio.event
async def leave_room(sid, data):
    room = data.get('stream_key')
    if room:
        sio.leave_room(sid, room)
        print(f"Client {sid} left room {room}")
        # Notify others in room
        await sio.emit('user_left', {'count': len(sio.rooms.get(room, {}))}, room=room)

@sio.event
async def send_chat(sid, data):
    room = data.get('stream_key')
    message = data.get('message')
    username = data.get('username', 'Anonymous')
    
    if room and message:
        await sio.emit('new_chat', {
            'username': username,
            'message': message,
            'timestamp': time.time()
        }, room=room)

async def on_shutdown(app):
    # Close all peer connections
    coros = [pc.close() for pc in pcs]
    await asyncio.gather(*coros)
    pcs.clear()
    
    # Clear broadcasters
    active_broadcasters.clear()

def create_webrtc_app():
    app = web.Application()
    sio.attach(app)
    
    # Add routes
    app.router.add_get("/webrtc", index)
    app.router.add_get("/webrtc/broadcast", broadcast_page)
    app.router.add_get("/webrtc/view/{stream_key}", viewer_page)
    app.router.add_get("/static/js/webrtc-client.js", javascript)
    app.router.add_post("/webrtc/offer", offer)
    
    # Add shutdown handler
    app.on_shutdown.append(on_shutdown)
    
    return app

def run_webrtc_server(host='0.0.0.0', port=5443):
    """Run the WebRTC server as a standalone application"""
    app = create_webrtc_app()
    ssl_context = get_ssl_context()
    
    web.run_app(app, host=host, port=port, ssl_context=ssl_context)

if __name__ == "__main__":
    run_webrtc_server()