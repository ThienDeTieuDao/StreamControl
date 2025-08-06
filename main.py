import threading
from app import app
from webrtc_server import create_webrtc_app, run_webrtc_server

def start_webrtc_server():
    """Start the WebRTC server in a separate thread"""
    run_webrtc_server(host="0.0.0.0", port=5443)

if __name__ == "__main__":
    # Start WebRTC server in a separate thread
    webrtc_thread = threading.Thread(target=start_webrtc_server, daemon=True)
    webrtc_thread.start()
    
    # Start Flask app
    app.run(host="0.0.0.0", port=5000, debug=True)
