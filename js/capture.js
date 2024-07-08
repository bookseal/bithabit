// capture.js

import { formatDate, formatTime, formatDuration, padZero } from './utils.js';

let videoElement;
let canvasElement;
let capturedImagesContainer;
let recordingStatusElement;
let durationElement;
let captureInterval;
let isCapturing = false;
let isCapturingComplete = false;
let startTime;
let duration;
let durationInterval;
let blinkInterval;

const CAPTURE_INTERVAL = 20; // seconds
const TWENTY_MINUTES = 20 * 60 * 1000; // 20 minutes in milliseconds

export function setupCapture(video, canvas, imagesContainer, recordingStatus, durationEl) {
    videoElement = video;
    canvasElement = canvas;
    capturedImagesContainer = imagesContainer;
    recordingStatusElement = recordingStatus;
    durationElement = durationEl;
}

export function startCapturing(_startTime) {
    isCapturing = true;
	startTime = _startTime;
    updateTimeDisplay();
    durationInterval = setInterval(updateDuration, 1000);
    showRecordingMessage();
    captureImage();
    captureInterval = setInterval(captureImage, CAPTURE_INTERVAL * 1000);
}

export function stopCapturing() {
    isCapturing = false;
    captureImage();
    clearInterval(captureInterval);
    clearInterval(durationInterval);
    recordingStatusElement.classList.add('d-none');
	return duration;
}

export function captureImage() {
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

function drawOverlay(context, canvasWidth, canvasHeight, barHeight) {
    const centerY = (canvasHeight - barHeight) / 2;
    const bottomY = canvasHeight - 10;

    context.globalAlpha = 0.5;
    context.fillStyle = 'white';
    context.fillRect(0, centerY, canvasWidth, barHeight);
    context.globalAlpha = 1.0;

    context.font = '30px Arial';
    context.fillStyle = 'black';
    context.textAlign = 'right';
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

function showRecordingMessage() {
    recordingStatusElement.classList.remove('d-none');
    recordingStatusElement.textContent = "Recording";
}

function updateTimeDisplay() {
    if (durationElement) durationElement.textContent = formatDuration(duration);
}

function updateDuration() {
    const now = new Date();
	duration = now - startTime;
    if (durationElement) durationElement.textContent = formatDuration(duration);
	if (duration >= TWENTY_MINUTES && !blinkInterval) {
		startBlinking();
	}
}

function startBlinking() {
    let isVisible = true;
    blinkInterval = setInterval(() => {
        isVisible = !isVisible;
        durationElement.style.visibility = isVisible ? 'visible' : 'hidden';
    }, 500); // Blink every 500ms
}


export function isCapturingInProgress() {
    return isCapturing;
}

export function isCaptureComplete() {
    return isCapturingComplete;
}