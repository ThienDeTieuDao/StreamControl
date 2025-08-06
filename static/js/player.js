document.addEventListener('DOMContentLoaded', function() {
    // Initialize Video.js player if it exists on the page
    const videoElement = document.getElementById('my-video');
    const audioElement = document.getElementById('my-audio');
    
    // Video player initialization
    if (videoElement) {
        const player = videojs('my-video', {
            controls: true,
            autoplay: false,
            preload: 'auto',
            fluid: true,
            playbackRates: [0.5, 1, 1.25, 1.5, 2],
            responsive: true,
            controlBar: {
                children: [
                    'playToggle',
                    'volumePanel',
                    'currentTimeDisplay',
                    'timeDivider',
                    'durationDisplay',
                    'progressControl',
                    'remainingTimeDisplay',
                    'playbackRateMenuButton',
                    'fullscreenToggle'
                ]
            }
        });
        
        // Add event listeners for analytics
        player.on('play', function() {
            console.log('Video playback started');
        });
        
        player.on('ended', function() {
            console.log('Video playback completed');
        });
        
        // Save playback position on timeupdate
        player.on('timeupdate', function() {
            // Only store if we're past 5 seconds to avoid storing positions for brief plays
            if (player.currentTime() > 5) {
                localStorage.setItem('videoPosition-' + videoElement.dataset.mediaId, player.currentTime());
            }
        });
        
        // Resume playback from saved position if available
        const mediaId = videoElement.dataset.mediaId;
        if (mediaId) {
            const savedPosition = localStorage.getItem('videoPosition-' + mediaId);
            if (savedPosition && !isNaN(savedPosition) && parseFloat(savedPosition) > 0) {
                player.on('loadedmetadata', function() {
                    // Ensure we don't seek past the end of the video
                    const seekPosition = Math.min(parseFloat(savedPosition), player.duration() - 5);
                    if (seekPosition > 0) {
                        player.currentTime(seekPosition);
                        console.log('Resumed video from position: ' + seekPosition);
                    }
                });
            }
        }
        
        // Keyboard shortcuts
        document.addEventListener('keydown', function(event) {
            // Only handle shortcuts if the player is in focus
            if (document.activeElement === document.body || 
                document.activeElement === videoElement || 
                document.activeElement.closest('.video-js')) {
                
                switch(event.key) {
                    case ' ':
                        // Space bar toggles play/pause
                        if (player.paused()) {
                            player.play();
                        } else {
                            player.pause();
                        }
                        event.preventDefault();
                        break;
                    case 'f':
                        // F toggles fullscreen
                        if (player.isFullscreen()) {
                            player.exitFullscreen();
                        } else {
                            player.requestFullscreen();
                        }
                        event.preventDefault();
                        break;
                    case 'm':
                        // M toggles mute
                        player.muted(!player.muted());
                        event.preventDefault();
                        break;
                    case 'ArrowRight':
                        // Right arrow seeks forward 10 seconds
                        player.currentTime(Math.min(player.currentTime() + 10, player.duration()));
                        event.preventDefault();
                        break;
                    case 'ArrowLeft':
                        // Left arrow seeks backward 10 seconds
                        player.currentTime(Math.max(player.currentTime() - 10, 0));
                        event.preventDefault();
                        break;
                    case '0':
                    case '1':
                    case '2':
                    case '3':
                    case '4':
                    case '5':
                    case '6':
                    case '7':
                    case '8':
                    case '9':
                        // Number keys seek to percentage
                        player.currentTime(player.duration() * parseInt(event.key) / 10);
                        event.preventDefault();
                        break;
                }
            }
        });
    }
    
    // Audio player initialization
    if (audioElement) {
        const player = videojs('my-audio', {
            controls: true,
            autoplay: false,
            preload: 'auto',
            playbackRates: [0.5, 1, 1.25, 1.5, 2],
            controlBar: {
                children: [
                    'playToggle',
                    'volumePanel',
                    'currentTimeDisplay',
                    'timeDivider',
                    'durationDisplay',
                    'progressControl',
                    'remainingTimeDisplay',
                    'playbackRateMenuButton'
                ]
            }
        });
        
        // Add event listeners for analytics
        player.on('play', function() {
            console.log('Audio playback started');
        });
        
        player.on('ended', function() {
            console.log('Audio playback completed');
        });
        
        // Save playback position on timeupdate
        player.on('timeupdate', function() {
            // Only store if we're past 5 seconds to avoid storing positions for brief plays
            if (player.currentTime() > 5) {
                localStorage.setItem('audioPosition-' + audioElement.dataset.mediaId, player.currentTime());
            }
        });
        
        // Resume playback from saved position if available
        const mediaId = audioElement.dataset.mediaId;
        if (mediaId) {
            const savedPosition = localStorage.getItem('audioPosition-' + mediaId);
            if (savedPosition && !isNaN(savedPosition) && parseFloat(savedPosition) > 0) {
                player.on('loadedmetadata', function() {
                    // Ensure we don't seek past the end of the audio
                    const seekPosition = Math.min(parseFloat(savedPosition), player.duration() - 5);
                    if (seekPosition > 0) {
                        player.currentTime(seekPosition);
                        console.log('Resumed audio from position: ' + seekPosition);
                    }
                });
            }
        }
        
        // Keyboard shortcuts for audio player
        document.addEventListener('keydown', function(event) {
            // Only handle shortcuts if the player is in focus
            if (document.activeElement === document.body || 
                document.activeElement === audioElement || 
                document.activeElement.closest('.video-js')) {
                
                switch(event.key) {
                    case ' ':
                        // Space bar toggles play/pause
                        if (player.paused()) {
                            player.play();
                        } else {
                            player.pause();
                        }
                        event.preventDefault();
                        break;
                    case 'm':
                        // M toggles mute
                        player.muted(!player.muted());
                        event.preventDefault();
                        break;
                    case 'ArrowRight':
                        // Right arrow seeks forward 10 seconds
                        player.currentTime(Math.min(player.currentTime() + 10, player.duration()));
                        event.preventDefault();
                        break;
                    case 'ArrowLeft':
                        // Left arrow seeks backward 10 seconds
                        player.currentTime(Math.max(player.currentTime() - 10, 0));
                        event.preventDefault();
                        break;
                }
            }
        });
    }
    
    // Handle media info display toggles
    const descriptionToggle = document.querySelector('.toggle-description');
    if (descriptionToggle) {
        descriptionToggle.addEventListener('click', function(e) {
            e.preventDefault();
            const descriptionContainer = document.querySelector('.media-description');
            descriptionContainer.classList.toggle('expanded');
            
            if (descriptionContainer.classList.contains('expanded')) {
                descriptionToggle.textContent = 'Show Less';
            } else {
                descriptionToggle.textContent = 'Show More';
            }
        });
    }

    // Update the data-media-id attribute for players if not already set
    const mediaIdElement = document.querySelector('[data-media-id]');
    if ((!videoElement || !videoElement.dataset.mediaId) && 
        (!audioElement || !audioElement.dataset.mediaId) && 
        mediaIdElement) {
        const mediaId = mediaIdElement.dataset.mediaId;
        if (videoElement) videoElement.dataset.mediaId = mediaId;
        if (audioElement) audioElement.dataset.mediaId = mediaId;
    }
});
