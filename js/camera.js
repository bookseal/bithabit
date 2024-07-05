// camera.js

let stream;
let videoElement;
let currentFacingMode = 'environment';

function isMobileDevice() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

async function initializeCamera() {
    try {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            throw new Error('Your browser does not support camera access');
        }

        const devices = await navigator.mediaDevices.enumerateDevices();
        const videoDevices = devices.filter(device => device.kind === 'videoinput');

        if (videoDevices.length === 0) {
            throw new Error('No camera detected on this device');
        }

        currentFacingMode = isMobileDevice() ? 'environment' : 'user';
        
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

        throw new Error(errorMessage);
    }
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
        throw new Error('Unable to switch camera.');
    }
}

function stopCamera() {
    if (stream) {
        stream.getTracks().forEach(track => track.stop());
    }
}

export function setupCamera(video) {
    videoElement = video;
    return {
        initialize: initializeCamera,
        switch: switchCamera,
        stop: stopCamera
    };
}