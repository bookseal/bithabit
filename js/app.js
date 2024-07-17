// app.js

import { setupCamera } from './camera.js';
import { createAndDisplayVideo } from './video.js';
import { setupCapture, startCapturing, stopCapturing, isCapturingInProgress, isCaptureComplete, pauseCapturing } from './capture.js';
import { submitAttendance } from './attendance.js';

let stream;
let videoElement;
let canvasElement;
let captureBtn;
let pauseBtn;
let switchCameraBtn;
let recordingStatusElement;
let durationElement;
let errorMessageElement;
let capturedImagesContainer;

let isCapturing = false;
let isFinish = false;
let captureInterval;
let durationInterval;
let blobUrl;
let cameraModule;
let startTime;
let duration;

async function initializeApp() {
    videoElement = document.getElementById('video');
    canvasElement = document.getElementById('canvas');
    captureBtn = document.getElementById('captureBtn');
	pauseBtn = document.getElementById('pauseBtn');
    switchCameraBtn = document.getElementById('switchCameraBtn');
    recordingStatusElement = document.getElementById('recordingStatus');
    durationElement = document.getElementById('duration');
    errorMessageElement = document.getElementById('errorMessage');
    capturedImagesContainer = document.getElementById('capturedImages');

	const userIDInput = document.getElementById('userID');
	const savedUserID = localStorage.getItem('userID');
	if (savedUserID) {
		userIDInput.value = savedUserID;
	}

	userIDInput.addEventListener('input', function () {
		localStorage.setItem('userID', userIDInput.value);
	});
	
    captureBtn.addEventListener('click', toggleCapturing);
    switchCameraBtn.addEventListener('click', switchCamera);
	pauseBtn.addEventListener('click', pauseCapturing);

    cameraModule = setupCamera(videoElement);
	setupCapture(videoElement, canvasElement, capturedImagesContainer, recordingStatusElement, durationElement);
	await cameraModule.initialize();
}

function waitForFinalCapture() {
    if (isCaptureComplete()) {
        const capturedImages = Array.from(document.querySelectorAll('.captured-image'));
        createAndDisplayVideo(capturedImages);
    } else {
        setTimeout(waitForFinalCapture, 100);
    }
}

async function toggleCapturing() {
	let id = document.getElementById('userID').value.toLowerCase();
	if (isFinish)
		;
    else if (isCapturingInProgress()) {
		isFinish = true;
		duration = stopCapturing();
        captureBtn.classList.remove('btn-danger');
        switchCameraBtn.disabled = false;
		await submitAttendance(id, startTime, duration);
        waitForFinalCapture();
		captureBtn.innerHTML = '<i class="fas fa-check"></i> 출섹체크완료';
		captureBtn.classList.add('btn-success');
		captureBtn.classList.remove('btn-danger');
		captureBtn.disabled = true;
		captureBtn.style.pointerEvents = 'none';
		captureBtn.style.backgroundColor = 'green';
		captureBtn.style.borderColor = 'green';
		captureBtn.style.color = 'white';
		captureBtn.style.border = '1px solid green';
		captureBtn.style.boxShadow = 'none';
		captureBtn.style.textShadow = 'none';
		captureBtn.style.transition = 'none';
		captureBtn.style.opacity = '0.5';
		captureBtn.style.cursor = 'default';
    } else if (!id) {
		alert("Please enter your ID before starting.");
	} else {
		startTime = new Date();
		startCapturing(startTime);
		captureBtn.innerHTML = '<i class="fas fa-stop"></i> Stop';
		captureBtn.classList.remove('btn-checking');
		captureBtn.classList.add('btn-danger');
		captureBtn.classList.remove('btn-danger');
		switchCameraBtn.disabled = true;
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

function cleanup() {
	cameraModule.stop();
	stopCapturing();
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

    if (blobUrl) {
        URL.revokeObjectURL(blobUrl);
        blobUrl = null;
    }
}
document.getElementById('userID').addEventListener('keypress', function(event) {
	if (event.key === 'Enter') {
		event.preventDefault(); // Prevent the default form submission
		document.getElementById('captureBtn').click(); // Programmatically click the capture button
	}
});

document.addEventListener('DOMContentLoaded', initializeApp);
window.addEventListener('beforeunload', cleanup);
window.addEventListener('unhandledrejection', function(event) {
    console.error('Unhandled promise rejection:', event.reason);
    handleError(event.reason, 'An unexpected error occurred. Please try again.');
});

function handleError(error, message) {
    console.error(message, error);
    errorMessageElement.textContent = message;
}