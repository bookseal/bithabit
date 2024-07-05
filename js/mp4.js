// mp4.js

import { formatDateTime } from './utils.js';

let videoElement;
let canvasElement;

export function setupMP4(video, canvas) {
    videoElement = video;
    canvasElement = canvas;
}

export async function createAndDisplayMP4(capturedImages) {
    if (capturedImages.length === 0) {
        console.log("No captured images!");
        return;
    }

    const loadingIndicator = createLoadingIndicator('Creating MP4...');
    document.body.appendChild(loadingIndicator);

    try {
        const videoBlob = await createMP4FromImages(capturedImages);
        const videoUrl = URL.createObjectURL(videoBlob);
        displayMP4(videoUrl);
    } catch (error) {
        console.error("Error in MP4 generation process:", error);
        alert("An error occurred while creating the MP4. Please try again.");
    } finally {
        document.body.removeChild(loadingIndicator);
    }
}

function createLoadingIndicator(message) {
    const loadingIndicator = document.createElement('div');
    loadingIndicator.textContent = message;
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
    return loadingIndicator;
}

async function createMP4FromImages(images) {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    const firstImage = images[0];
    canvas.width = firstImage.naturalWidth;
    canvas.height = firstImage.naturalHeight;

    const stream = canvas.captureStream(30); // 30 FPS
    const mediaRecorder = new MediaRecorder(stream, { mimeType: 'video/webm' });

    const chunks = [];
    mediaRecorder.ondataavailable = (e) => chunks.push(e.data);

    const recordingPromise = new Promise((resolve) => {
        mediaRecorder.onstop = () => {
            const blob = new Blob(chunks, { type: 'video/webm' });
            resolve(blob);
        };
    });

    mediaRecorder.start();

    for (let i = images.length - 1; i >= 0; i--) {
        ctx.drawImage(images[i], 0, 0);
        await new Promise(resolve => setTimeout(resolve, 100)); // 100ms delay between frames
    }

    mediaRecorder.stop();

    return recordingPromise;
}

function displayMP4(videoUrl) {
    const mp4Container = document.getElementById('mp4-container');
    if (!mp4Container) {
        console.error('MP4 container not found');
        return;
    }

    mp4Container.innerHTML = '';
    const videoElement = document.createElement('video');
    videoElement.src = videoUrl;
    videoElement.controls = true;
    videoElement.style.maxWidth = '100%';
    mp4Container.appendChild(videoElement);

    const now = new Date();
    const fileName = `BitHabit-${formatDateTime(now)}.mp4`;

    const downloadButton = createButton(videoUrl, fileName, 'Download', 'btn-primary');
    const shareButton = createButton(null, null, 'Share', 'btn-secondary');
    shareButton.addEventListener('click', () => shareMP4(videoUrl, fileName));

    mp4Container.appendChild(downloadButton);
    mp4Container.appendChild(shareButton);

    mp4Container.style.display = 'block';
    setTimeout(() => {
        mp4Container.scrollIntoView({behavior: 'smooth', block: 'start'});
    }, 100);
}

function createButton(url, fileName, text, className) {
    const button = document.createElement(url ? 'a' : 'button');
    if (url) {
        button.href = url;
        button.download = fileName;
    }
    button.textContent = text;
    button.className = `btn ${className} mt-2 mr-2`;
    return button;
}

async function shareMP4(videoUrl, fileName) {
    try {
        const response = await fetch(videoUrl);
        const blob = await response.blob();
        const file = new File([blob], fileName, { type: "video/mp4" });
        
        if (navigator.share) {
            await navigator.share({
                files: [file],
                title: 'Check out this video!',
                text: fileName
            });
        } else {
            alert('Direct sharing is not supported. Please copy this URL: ' + videoUrl);
        }
    } catch (error) {
        console.error('Error sharing MP4:', error);
    }
}