// app.js

import { setupCamera } from './camera.js';
import { createAndDisplayVideo } from './video.js';
import { setupCapture, startCapturing, stopCapturing, isCapturingInProgress, isCaptureComplete } from './capture.js';

let stream;
let videoElement;
let canvasElement;
let captureBtn;
let switchCameraBtn;
let recordingStatusElement;
let durationElement;
let errorMessageElement;
let capturedImagesContainer;

let isCapturing = false;
let captureInterval;
let durationInterval;
let blobUrl;
let cameraModule;

async function initializeApp() {
    videoElement = document.getElementById('video');
    canvasElement = document.getElementById('canvas');
    captureBtn = document.getElementById('captureBtn');
    switchCameraBtn = document.getElementById('switchCameraBtn');
    recordingStatusElement = document.getElementById('recordingStatus');
    durationElement = document.getElementById('duration');
    errorMessageElement = document.getElementById('errorMessage');
    capturedImagesContainer = document.getElementById('capturedImages');

    captureBtn.addEventListener('click', toggleCapturing);
    switchCameraBtn.addEventListener('click', switchCamera);

    cameraModule = setupCamera(videoElement);
	setupCapture(videoElement, canvasElement, capturedImagesContainer, recordingStatusElement, durationElement);
    try {    
        await cameraModule.initialize();
    } catch (error) {
        handleError(error, error.message);
        return;
    }
}

function waitForFinalCapture() {
    if (isCaptureComplete()) {
        const capturedImages = Array.from(document.querySelectorAll('.captured-image'));
        createAndDisplayVideo(capturedImages);
    } else {
        setTimeout(waitForFinalCapture, 100);
    }
}

function toggleCapturing() {
    if (isCapturingInProgress()) {
        stopCapturing();
        captureBtn.innerHTML = '<i class="fas fa-camera"></i> Start';
        captureBtn.classList.remove('btn-danger');
        switchCameraBtn.disabled = false;
        waitForFinalCapture();
    } else {
        startCapturing();
        captureBtn.innerHTML = '<i class="fas fa-stop"></i> Stop';
        captureBtn.classList.add('btn-danger');
        switchCameraBtn.disabled = true;
    }
}

















function createShareableLink(blob) {
    if (blobUrl) {
        URL.revokeObjectURL(blobUrl);
    }
    blobUrl = URL.createObjectURL(blob);
    setupShareButton(blobUrl);
}

function setupShareButton(blobUrl) {
	const shareButton = document.getElementById('shareButton');
	shareButton.addEventListener('click', () => shareGif(blobUrl));
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

// async function createAndDisplayGif() {
//     const capturedImages = Array.from(document.querySelectorAll('.captured-image'));
//     if (capturedImages.length === 0) {
//         console.log("No captured images!");
//         return;
//     }

//     const loadingIndicator = document.createElement('div');
//     loadingIndicator.textContent = 'Creating GIF...';
//     loadingIndicator.style.cssText = `
//         position: fixed;
//         top: 50%;
//         left: 50%;
//         transform: translate(-50%, -50%);
//         padding: 20px;
//         background: rgba(0,0,0,0.7);
//         color: white;
//         border-radius: 10px;
//         z-index: 1000;
//     `;
//     document.body.appendChild(loadingIndicator);

//     try {
//         const gif = new GIF({
//             workers: 2,
//             quality: 10,
//             width: capturedImages[0].naturalWidth,
//             height: capturedImages[0].naturalHeight
//         });

//         // Add frames in reverse order
//         for (let i = capturedImages.length - 1; i >= 0; i--) {
//             gif.addFrame(capturedImages[i], {delay: 100});
//         }

//         gif.on('finished', function(blob) {
// 			createShareableLink(blob);
//             const gifUrl = URL.createObjectURL(blob);
//             displayGif(gifUrl);
//             document.body.removeChild(loadingIndicator);
//         });

//         gif.render();
//     } catch (error) {
//         console.error("Error in GIF generation process:", error);
//         document.body.removeChild(loadingIndicator);
//         alert("An error occurred while creating the GIF. Please try again.");
//     }
// }

// function displayGif(gifUrl) {
//     const gifContainer = document.getElementById('gif-container');
//     if (!gifContainer) {
//         console.error('GIF container not found');
//         return;
//     }

//     gifContainer.innerHTML = '';
//     const gifImage = document.createElement('img');
//     gifImage.src = gifUrl;
//     gifImage.alt = 'Generated GIF';
//     gifImage.style.maxWidth = '100%';
//     gifContainer.appendChild(gifImage);

//     const now = new Date();
//     const date = now.toLocaleDateString().replace(/\//g, '-'); // 날짜 형식을 "yyyy-mm-dd"로 변환
//     const time = now.toLocaleTimeString().replace(/:/g, '-'); // 시간 형식을 "HH-MM-SS"로 변환
//     const fileName = `BitHabit-${date}-${time}.gif`;

//     const downloadButton = document.createElement('a');
//     downloadButton.href = gifUrl;
//     downloadButton.download = fileName;
//     downloadButton.textContent = '다운로드';
//     downloadButton.className = 'btn btn-primary mt-2';
//     gifContainer.appendChild(downloadButton);

//     const shareButton = document.createElement('button');
//     shareButton.textContent = '결과를 카톡에 공유';
//     shareButton.className = 'btn btn-secondary mt-2 ml-2';
//     shareButton.addEventListener('click', () => shareGif(gifUrl, fileName));
//     gifContainer.appendChild(shareButton);

//     gifContainer.style.display = 'block';
//     setTimeout(() => {
//         gifContainer.scrollIntoView({behavior: 'smooth', block: 'start'});
//     }, 100);
// }

// async function shareGif(blobUrl, fileName) {
//     try {
//         const response = await fetch(blobUrl);
//         const blob = await response.blob();
//         const file = new File([blob], fileName, { type: "image/gif" });
        
//         if (navigator.share) {
//             await navigator.share({
//                 files: [file],
//                 title: 'Check out this GIF!',
//                 text: fileName
//             });
//         } else {
//             alert('직접 공유가 지원되지 않습니다. URL을 복사해 주세요: ' + blobUrl);
//         }
//     } catch (error) {
//         console.error('공유 중 오류 발생:', error);
//     }
// }