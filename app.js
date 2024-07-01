const CAPTURE_INTERVAL = 1; // Capture interval in seconds

let stream;
let videoElement;
let canvasElement;
let captureBtn;
let switchCameraBtn;
let countdownElement;
let durationElement;
let errorMessageElement;
let capturedImagesContainer;

let isCapturing = false;
let countdownInterval;
let captureInterval;
let countdown;
let startTime;
let duration;
let durationInterval;
let currentFacingMode = 'environment';

document.addEventListener('DOMContentLoaded', initializeApp);

function isMobileDevice() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

async function initializeApp() {
    videoElement = document.getElementById('video');
    canvasElement = document.getElementById('canvas');
    captureBtn = document.getElementById('captureBtn');
    switchCameraBtn = document.getElementById('switchCameraBtn');
    countdownElement = document.getElementById('countdown');
    durationElement = document.getElementById('duration');
    errorMessageElement = document.getElementById('errorMessage');
    capturedImagesContainer = document.getElementById('capturedImages');

    captureBtn.addEventListener('click', toggleCapturing);
    switchCameraBtn.addEventListener('click', switchCamera);

    try {
        await initializeCamera();
    } catch (error) {
        console.error('Camera initialization error:', error);
        errorMessageElement.textContent = 'Unable to initialize the camera. Please check your permissions and refresh the page.';
    }
}

async function initializeCamera() {
    try {
        currentFacingMode = isMobileDevice() ? 'environment' : 'user';
        stream = await navigator.mediaDevices.getUserMedia({ 
            video: { facingMode: currentFacingMode } 
        });
        videoElement.srcObject = stream;
        console.log('Camera access successful');
    } catch (error) {
        console.error('Camera access error:', error);
        errorMessageElement.textContent = 'Unable to access the camera. Please check your permissions and try again.';
        throw error;
    }
}

function startCapturing() {
    startTime = new Date();
    updateTimeDisplay();
    durationInterval = setInterval(updateDuration, 1000);
    countdown = CAPTURE_INTERVAL;
    startCountdown();
}

function startCountdown() {
    countdownElement.classList.remove('d-none');
    updateCountdown();
    countdownInterval = setInterval(updateCountdown, 1000);
}

function updateCountdown() {
    if (!isCapturing) {
        clearInterval(countdownInterval);
        countdownElement.classList.add('d-none');
        return;
    }

    if (countdown > 0) {
        countdownElement.textContent = "Recording";
        countdown--;
    } else {
        countdownElement.textContent = '찰칵';
        clearInterval(countdownInterval);
        captureImage();
        countdown = CAPTURE_INTERVAL;
        setTimeout(startCountdown, 100);
    }
}

function stopCapturing() {
    clearInterval(countdownInterval);
    clearInterval(durationInterval);
    countdownElement.classList.add('d-none');
    isCapturing = false;
}

function toggleCapturing() {
    isCapturing = !isCapturing;

    if (isCapturing) {
        startCapturing();
        captureBtn.innerHTML = '<i class="fas fa-stop"></i> Stop';
        captureBtn.classList.add('btn-danger');
        switchCameraBtn.disabled = true;
    } else {
        stopCapturing();
        captureBtn.innerHTML = '<i class="fas fa-camera"></i> Start';
        captureBtn.classList.remove('btn-danger');
        switchCameraBtn.disabled = false;
        createAndDisplayGif();
    }
}

function drawOverlay(context, canvasWidth, canvasHeight, barHeight) {
    const centerY = (canvasHeight - barHeight) / 2;
    const bottomY = canvasHeight - 10;

    context.globalAlpha = 0.5;
    context.fillStyle = 'white';
    context.fillRect(0, centerY, canvasWidth, barHeight);
    context.globalAlpha = 1.0;

    context.font = '30px Arial';
    context.fillStyle = 'black';
    context.textAlign = 'center';
    context.fillText('BitHabit', canvasWidth / 2, centerY + barHeight / 2 + 10);

    const durationText = durationElement.textContent;
    context.textAlign = 'left';
    context.fillText(durationText, 10, centerY + barHeight / 2 + 10);

    const now = new Date();
    const dateTimeText = `${formatDate(now)} ${formatTime(now)}`;
    context.font = '20px Arial';
    context.textAlign = 'center';
    context.fillStyle = 'white';
    context.strokeStyle = 'black';
    context.lineWidth = 3;
    context.strokeText(dateTimeText, canvasWidth / 2, bottomY);
    context.fillText(dateTimeText, canvasWidth / 2, bottomY);
}

function captureImage() {
    if (!isCapturing) return;

    const context = canvasElement.getContext('2d');
    const barHeight = 50;

    canvasElement.width = videoElement.videoWidth;
    canvasElement.height = videoElement.videoHeight;

    context.drawImage(videoElement, 0, 0);
    drawOverlay(context, canvasElement.width, canvasElement.height, barHeight);

    const imageDataUrl = canvasElement.toDataURL('image/jpeg');
    const imgElement = document.createElement('img');
    imgElement.src = imageDataUrl;
    imgElement.className = 'captured-image';
    capturedImagesContainer.prepend(imgElement);
}

async function switchCamera() {
    currentFacingMode = currentFacingMode === 'user' ? 'environment' : 'user';
    
    try {
        const newStream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: currentFacingMode }
        });
        videoElement.srcObject = newStream;
        stream = newStream;
    } catch (error) {
        console.error('Camera switch error:', error);
        errorMessageElement.textContent = 'Unable to switch camera.';
    }
}

function updateTimeDisplay() {
    if (durationElement) durationElement.textContent = formatDuration(duration);
}

function updateDuration() {
    const now = new Date();
    duration = now - startTime;
    if (durationElement) durationElement.textContent = formatDuration(duration);
}

async function createAndDisplayGif() {
    const capturedImages = Array.from(document.querySelectorAll('.captured-image'));
    if (capturedImages.length === 0) {
        console.log("No captured images!");
        return;
    }

    const loadingIndicator = document.createElement('div');
    loadingIndicator.textContent = 'Creating GIF...';
    loadingIndicator.style.cssText = `
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        padding: 20px;
        background: rgba(0,0,0,0.7);
        color: white;
        border-radius: 10px;
        z-index: 1000;
    `;
    document.body.appendChild(loadingIndicator);

    try {
        const gif = new GIF({
            workers: 2,
            quality: 10,
            width: capturedImages[0].naturalWidth,
            height: capturedImages[0].naturalHeight
        });

        capturedImages.forEach(img => gif.addFrame(img, {delay: 100}));

        gif.on('finished', function(blob) {
            const gifUrl = URL.createObjectURL(blob);
            displayGif(gifUrl);
            document.body.removeChild(loadingIndicator);
        });

        gif.render();
    } catch (error) {
        console.error("Error in GIF generation process:", error);
        document.body.removeChild(loadingIndicator);
        alert("An error occurred while creating the GIF. Please try again.");
    }
}

function displayGif(gifUrl) {
    const gifContainer = document.getElementById('gif-container');
    if (!gifContainer) {
        console.error('GIF container not found');
        return;
    }

    gifContainer.innerHTML = '';
    const gifImage = document.createElement('img');
    gifImage.src = gifUrl;
    gifImage.alt = 'Generated GIF';
    gifImage.style.maxWidth = '100%';
    gifContainer.appendChild(gifImage);

    const downloadButton = document.createElement('a');
    downloadButton.href = gifUrl;
    downloadButton.download = 'generated_gif.gif';
    downloadButton.textContent = 'Download GIF';
    downloadButton.className = 'btn btn-primary mt-2';
    gifContainer.appendChild(downloadButton);

    gifContainer.style.display = 'block';
    setTimeout(() => {
        gifContainer.scrollIntoView({behavior: 'smooth', block: 'start'});
    }, 100);
}

// Utility functions
function formatDuration(ms) {
    if (!ms) return '00:00:00';
    const totalSeconds = Math.floor(ms / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    return `${padZero(hours)}:${padZero(minutes)}:${padZero(seconds)}`;
}

function formatDate(date) {
    return `${date.getFullYear()}-${padZero(date.getMonth() + 1)}-${padZero(date.getDate())}`;
}

function formatTime(date) {
    return `${padZero(date.getHours())}-${padZero(date.getMinutes())}-${padZero(date.getSeconds())}`;
}

function padZero(num) {
    return num.toString().padStart(2, '0');
}

function handleError(error, message) {
    console.error(message, error);
    errorMessageElement.textContent = message;
}

function checkDeviceSupport() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        handleError(null, 'Your device does not support the required media features.');
        return false;
    }
    return true;
}

function cleanup() {
    if (stream) {
        stream.getTracks().forEach(track => track.stop());
    }
    isCapturing = false;
    clearInterval(countdownInterval);
    clearInterval(durationInterval);
    countdownElement.classList.add('d-none');
    if (captureBtn) {
        captureBtn.innerHTML = '<i class="fas fa-camera"></i> Start';
        captureBtn.classList.remove('btn-danger');
    }
    if (switchCameraBtn) switchCameraBtn.disabled = false;
    updateTimeDisplay();
}

window.addEventListener('beforeunload', cleanup);

window.addEventListener('unhandledrejection', function(event) {
    console.error('Unhandled promise rejection:', event.reason);
    handleError(event.reason, 'An unexpected error occurred. Please try again.');
});

document.addEventListener('DOMContentLoaded', function() {
    if (checkDeviceSupport()) {
        initializeApp().catch(error => {
            handleError(error, 'Failed to initialize the application. Please refresh the page and try again.');
        });
    }
});