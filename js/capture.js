// capture.js

import { formatDate, formatTime, formatDuration, padZero } from './utils.js';

let videoElement;
let canvasElement;
let capturedImagesContainer;
let recordingStatusElement;
let durationElement;
let captureInterval;
let isCapturing = false;
let isPaused = false;
let isCapturingComplete = false;
let startTime;
let pauseStartTime;
let totalPausedTime = 0;
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

export function pauseCapturing() {
	if (isPaused) {
		isPaused = false;
		totalPausedTime += new Date() - pauseStartTime;
		pauseStartTime = null;
		pauseBtn.textContent = 'Pause';
		captureInterval = setInterval(captureImage, CAPTURE_INTERVAL * 1000);
		durationInterval = setInterval(updateDuration, 1000);
		stopBlinking();
	} else {
		isPaused = true;
		pauseStartTime = new Date();
		clearInterval(captureInterval);
		clearInterval(durationInterval);
		pauseBtn.textContent = 'Resume';
		startBlinking();
	}
}

export function startCapturing(_startTime) {
    isCapturing = true;
	isPaused = false;
	startTime = _startTime;
    updateTimeDisplay();
    durationInterval = setInterval(updateDuration, 1000);
    showRecordingMessage();
    captureImage();
    captureInterval = setInterval(captureImage, CAPTURE_INTERVAL * 1000);
}

export function stopCapturing() {
    isCapturing = false;
	isPaused = false;
    captureImage();
    clearInterval(captureInterval);
    clearInterval(durationInterval);
    recordingStatusElement.classList.add('d-none');
	return duration;
}

export function captureImage() {
	if (isPaused) return;
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

    // Draw semi-transparent white bar
    context.globalAlpha = 0.5;
    context.fillStyle = 'white';
    context.fillRect(0, centerY, canvasWidth, barHeight);
    context.globalAlpha = 1.0;

    // Set font properties
    context.font = '30px Arial';
    context.fillStyle = 'black';

    // Draw BitHabit text on the right
    context.textAlign = 'right';
    context.fillText('BitHabit', canvasWidth - 10, centerY + barHeight / 2 + 10);

    // Draw user ID in the center
    const userId = document.getElementById('userID').value; // Get user ID from input field
    context.textAlign = 'center';
    context.fillText(userId, canvasWidth / 2, centerY + barHeight / 2 + 10);

    // Draw duration text on the left 
    const durationText = durationElement.textContent;
    context.textAlign = 'left';
    context.fillText(durationText, 10, centerY + barHeight / 2 + 10);

    // Draw date and time at the bottom
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
	duration = now - startTime - totalPausedTime;
    if (durationElement) durationElement.textContent = formatDuration(duration);
	if (duration >= TWENTY_MINUTES && !blinkInterval) {
		startBlinking();
		playBeepSound();
	}
}

function playBeepSound() {
	const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);

    oscillator.type = 'sine'; // 비프음의 타입 (sine, square, sawtooth, triangle)
    oscillator.frequency.setValueAtTime(440, audioContext.currentTime); // 주파수 설정 (440Hz는 A4음)
    gainNode.gain.setValueAtTime(1, audioContext.currentTime); // 볼륨 설정

    oscillator.start();
    oscillator.stop(audioContext.currentTime + 0.5); // 0.5초 후에 소리 끔
}

function startBlinking() {
    let isVisible = true;
    blinkInterval = setInterval(() => {
        isVisible = !isVisible;
        durationElement.style.visibility = isVisible ? 'visible' : 'hidden';
    }, 500); // Blink every 500ms
}

function stopBlinking() {
	clearInterval(blinkInterval);
	blinkInterval = null;
	durationElement.style.visibility = 'visible';
}

export function isCapturingInProgress() {
    return isCapturing;
}

export function isCaptureComplete() {
    return isCapturingComplete;
}