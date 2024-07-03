const CAPTURE_INTERVAL = 15;

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
let isCapturingComplete = false;
let blobUrl; // 전역 변수로 선언하여 다른 함수에서도 접근 가능하게 합니다.


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
        // 브라우저의 카메라 지원 여부 확인
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            throw new Error('Your browser does not support camera access');
        }

        // 사용 가능한 카메라 목록 가져오기
        const devices = await navigator.mediaDevices.enumerateDevices();
        const videoDevices = devices.filter(device => device.kind === 'videoinput');

        if (videoDevices.length === 0) {
            throw new Error('No camera detected on this device');
        }

        currentFacingMode = isMobileDevice() ? 'environment' : 'user';
        
        // 카메라 접근 시도
        stream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: currentFacingMode }
        });

        videoElement.srcObject = stream;
        console.log('Camera access successful');

    } catch (error) {
        console.error('Camera access error:', error);
        
        let errorMessage = 'This application requires a camera to function. ';
        
        if (error.name === 'NotAllowedError') {
            errorMessage += 'Please grant camera permission and reload the page.';
        } else if (error.name === 'NotFoundError' || error.message.includes('No camera detected')) {
            errorMessage += 'No camera detected on this device. The application cannot run.';
        } else if (error.name === 'NotSupportedError') {
            errorMessage += 'Your browser does not support camera access. Please use a different browser.';
        } else {
            errorMessage += 'An unexpected error occurred. The application cannot run.';
        }

        errorMessageElement.textContent = errorMessage;
        disableAllCameraFunctions();
        throw error;
    }
}

function disableAllCameraFunctions() {
    // 모든 카메라 관련 기능 비활성화
    if (captureBtn) captureBtn.disabled = true;
    if (switchCameraBtn) switchCameraBtn.disabled = true;
    if (videoElement) videoElement.style.display = 'none';

    // 추가적인 UI 요소들도 필요에 따라 비활성화
}

// 기존의 initializeApp 함수 내에서 initializeCamera 호출 후 에러 처리
export async function initializeApp() {
    // ... 기존 코드 ...

    try {
        await initializeCamera();
    } catch (error) {
        handleError(error, 'Camera initialization failed. The application cannot run.');
        return; // 초기화 중단
    }

    // ... 나머지 초기화 코드 ...
}

function startCapturing() {
    startTime = new Date();
    updateTimeDisplay();
    durationInterval = setInterval(updateDuration, 1000);
    showRecordingMessage();
    
    // Capture an image immediately when starting
    captureImage();
    
    // Set interval for subsequent captures
    captureInterval = setInterval(captureImage, CAPTURE_INTERVAL * 1000);
}

function showRecordingMessage() {
    countdownElement.classList.remove('d-none');
    countdownElement.textContent = "Recording";
}

function stopCapturing() {
    // Capture a final image before stopping
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
        // Wait for the final capture to complete before creating the GIF
        waitForFinalCapture();
    }
}

function waitForFinalCapture() {
    if (isCapturingComplete) {
        createAndDisplayGif();
    } else {
        setTimeout(waitForFinalCapture, 100); // Check again in 100ms
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


function createShareableLink(blob) {
    if (blobUrl) {
        URL.revokeObjectURL(blobUrl); // 기존 URL이 있다면 해제
    }
    blobUrl = URL.createObjectURL(blob);
    setupShareButton(blobUrl);
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