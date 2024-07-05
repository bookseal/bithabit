// app.js

import { setupCamera } from './camera.js';
import { formatDateTime, formatDuration, formatDate, formatTime, padZero } from './utils.js';
import { setupMP4, createAndDisplayMP4 } from './mp4.js';

const CAPTURE_INTERVAL = 10;

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
let captureInterval;
let startTime;
let duration;
let durationInterval;
let currentFacingMode = 'environment';
let isCapturingComplete = false;
let blobUrl;
let cameraModule;

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

    cameraModule = setupCamera(videoElement);
	setupMP4(videoElement, canvasElement);

    try {
        await cameraModule.initialize();
    } catch (error) {
        handleError(error, error.message);
        return;
    }
}

function waitForFinalCapture() {
    if (isCapturingComplete) {
		const capturedImages = Array.from(document.querySelectorAll('.captured-image'));
        createAndDisplayMP4(capturedImages);
        // createAndDisplayGif();
    } else {
        setTimeout(waitForFinalCapture, 100);
    }
}

async function switchCamera() {
    try {
        await cameraModule.switch();
    } catch (error) {
        console.error('Camera switch error:', error);
        errorMessageElement.textContent = 'Unable to switch camera.';
    }
}

function disableAllCameraFunctions() {
    if (captureBtn) captureBtn.disabled = true;
    if (switchCameraBtn) switchCameraBtn.disabled = true;
    if (videoElement) videoElement.style.display = 'none';
}


function startCapturing() {
    startTime = new Date();
    updateTimeDisplay();
    durationInterval = setInterval(updateDuration, 1000);
    showRecordingMessage();
    captureImage();
    captureInterval = setInterval(captureImage, CAPTURE_INTERVAL * 1000);
}

function showRecordingMessage() {
    countdownElement.classList.remove('d-none');
    countdownElement.textContent = "Recording";
}

function stopCapturing() {
    captureImage();
    clearInterval(captureInterval);
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
        waitForFinalCapture();
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
    isCapturingComplete = false;
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
    imgElement.onload = () => {
        capturedImagesContainer.prepend(imgElement);
        // Limit the number of displayed images (e.g., to 20)
        const maxDisplayedImages = 200;
        while (capturedImagesContainer.children.length > maxDisplayedImages) {
            capturedImagesContainer.removeChild(capturedImagesContainer.lastChild);
        }
        isCapturingComplete = true;
    };
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

        // Add frames in reverse order
        for (let i = capturedImages.length - 1; i >= 0; i--) {
            gif.addFrame(capturedImages[i], {delay: 100});
        }

        gif.on('finished', function(blob) {
			createShareableLink(blob);
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

function createShareableLink(blob) {
    if (blobUrl) {
        URL.revokeObjectURL(blobUrl); // 기존 URL이 있다면 해제
    }
    blobUrl = URL.createObjectURL(blob);
    setupShareButton(blobUrl);
}

function setupShareButton(blobUrl) {
	const shareButton = document.getElementById('shareButton');
	shareButton.addEventListener('click', () => shareGif(blobUrl));
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

    const now = new Date();
    const date = now.toLocaleDateString().replace(/\//g, '-'); // 날짜 형식을 "yyyy-mm-dd"로 변환
    const time = now.toLocaleTimeString().replace(/:/g, '-'); // 시간 형식을 "HH-MM-SS"로 변환
    const fileName = `BitHabit-${date}-${time}.gif`;

    const downloadButton = document.createElement('a');
    downloadButton.href = gifUrl;
    downloadButton.download = fileName;
    downloadButton.textContent = '다운로드';
    downloadButton.className = 'btn btn-primary mt-2';
    gifContainer.appendChild(downloadButton);

    const shareButton = document.createElement('button');
    shareButton.textContent = '결과를 카톡에 공유';
    shareButton.className = 'btn btn-secondary mt-2 ml-2';
    shareButton.addEventListener('click', () => shareGif(gifUrl, fileName));
    gifContainer.appendChild(shareButton);

    gifContainer.style.display = 'block';
    setTimeout(() => {
        gifContainer.scrollIntoView({behavior: 'smooth', block: 'start'});
    }, 100);
}

async function shareGif(blobUrl, fileName) {
    try {
        const response = await fetch(blobUrl);
        const blob = await response.blob();
        const file = new File([blob], fileName, { type: "image/gif" });
        
        if (navigator.share) {
            await navigator.share({
                files: [file],
                title: 'Check out this GIF!',
                text: fileName
            });
        } else {
            alert('직접 공유가 지원되지 않습니다. URL을 복사해 주세요: ' + blobUrl);
        }
    } catch (error) {
        console.error('공유 중 오류 발생:', error);
    }
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
    clearInterval(captureInterval);
    clearInterval(durationInterval);
    countdownElement.classList.add('d-none');
    if (captureBtn) {
        captureBtn.innerHTML = '<i class="fas fa-camera"></i> Start';
        captureBtn.classList.remove('btn-danger');
    }
    if (switchCameraBtn) switchCameraBtn.disabled = false;
    updateTimeDisplay();

    // Blob URL 해제
    if (blobUrl) {
        URL.revokeObjectURL(blobUrl);
        blobUrl = null;
    }
}

document.addEventListener('DOMContentLoaded', initializeApp);
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