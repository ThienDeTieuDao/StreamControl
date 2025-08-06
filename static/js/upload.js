document.addEventListener('DOMContentLoaded', function() {
    const uploadForm = document.getElementById('uploadForm');
    const uploadButton = document.getElementById('uploadButton');
    const uploadProgress = document.getElementById('uploadProgress');
    const progressBar = uploadProgress.querySelector('.progress-bar');
    
    if (uploadForm) {
        uploadForm.addEventListener('submit', function(e) {
            const fileInput = document.getElementById('media_file');
            const titleInput = document.getElementById('title');
            
            // Basic validation
            if (!fileInput.files.length) {
                e.preventDefault();
                alert('Please select a file to upload');
                return;
            }
            
            if (!titleInput.value.trim()) {
                e.preventDefault();
                alert('Please enter a title');
                return;
            }
            
            // File size validation (max 1GB)
            const maxSize = 1024 * 1024 * 1024; // 1GB in bytes
            const fileSize = fileInput.files[0].size;
            
            if (fileSize > maxSize) {
                e.preventDefault();
                alert('File size exceeds the maximum allowed size (1GB)');
                return;
            }
            
            // Show progress bar for visual feedback
            uploadProgress.classList.remove('d-none');
            uploadButton.disabled = true;
            uploadButton.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i> Uploading...';
            
            // Simulate progress (since we don't have XHR upload)
            let progress = 0;
            const interval = setInterval(function() {
                progress += Math.random() * 10;
                if (progress > 95) {
                    clearInterval(interval);
                    progress = 95; // Cap at 95% until the form actually submits
                }
                progressBar.style.width = progress + '%';
                progressBar.setAttribute('aria-valuenow', progress);
            }, 500);
        });
    }
    
    // File input change handler to show selected filename
    const fileInput = document.getElementById('media_file');
    if (fileInput) {
        fileInput.addEventListener('change', function() {
            const fileName = this.files[0]?.name;
            const fileSize = this.files[0]?.size;
            
            if (fileName) {
                // Format file size
                let formattedSize;
                if (fileSize < 1024 * 1024) {
                    formattedSize = (fileSize / 1024).toFixed(2) + ' KB';
                } else if (fileSize < 1024 * 1024 * 1024) {
                    formattedSize = (fileSize / (1024 * 1024)).toFixed(2) + ' MB';
                } else {
                    formattedSize = (fileSize / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
                }
                
                // Set custom text for the file input
                const small = fileInput.nextElementSibling;
                small.innerHTML = `Selected: <strong>${fileName}</strong> (${formattedSize})`;
            }
        });
    }
});
