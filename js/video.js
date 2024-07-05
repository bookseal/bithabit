// video.js

import { formatDateTime } from './utils.js';

let videoElement;
let canvasElement;

export function setupVideo(video, canvas) {
    videoElement = video;
    canvasElement = canvas;
}

export async function createAndDisplayVideo(capturedImages) {
    if (capturedImages.length === 0) {
        console.log("No captured images!");
        return;
    }
    console.log(`Starting video creation with ${capturedImages.length} images`);
    const loadingIndicator = createLoadingIndicator('Creating animated GIF...');
    document.body.appendChild(loadingIndicator);
    try {
        console.log('Calling createGIFFromImages...');
        const gifBlob = await createGIFFromImages(capturedImages);
        console.log('GIF blob created, size:', gifBlob.size);
        const gifUrl = URL.createObjectURL(gifBlob);
        console.log('GIF URL created');
        displayVideo(gifUrl, 'gif');
        console.log('Video displayed');
    } catch (error) {
        console.error("Error in GIF generation process:", error);
        alert("An error occurred while creating the animated GIF. Please try again. Error: " + error.message);
    } finally {
        document.body.removeChild(loadingIndicator);
        console.log('Loading indicator removed');
    }
}

async function createGIFFromImages(images) {
    return new Promise((resolve, reject) => {
        console.log('Starting GIF creation...');
        const gif = new GIF({
            workers: 1,
            quality: 5,
            width: images[0].naturalWidth,
            height: images[0].naturalHeight,
            workerScript: 'js/gif.worker.js',
            createCanvas: function(width, height) {
                const canvas = document.createElement('canvas');
                canvas.width = width;
                canvas.height = height;
                const ctx = canvas.getContext('2d', { willReadFrequently: true });
                return canvas;
            }
        });

        console.log('GIF object created. Adding frames...');
        for (let i = images.length - 1; i >= 0; i--) {
            try {
                gif.addFrame(images[i], {delay: 200});
                console.log(`Added frame ${images.length - i} of ${images.length}`);
            } catch (error) {
                console.error(`Error adding frame ${images.length - i}:`, error);
                reject(error);
                return;
            }
        }

        console.log('All frames added. Starting render...');
        gif.on('progress', (p) => {
			console.log(`Rendering progress: ${(p * 100).toFixed(2)}%`);
			updateProgressBar(p);
		});

        gif.on('finished', function(blob) {
            console.log('GIF rendering finished');
            resolve(blob);
        });

        gif.render();

        setTimeout(() => {
            reject(new Error('GIF creation timed out after 60 seconds'));
        }, 60000); // 60 second timeout
    });
}

function updateProgressBar(progress) {
    const progressBar = document.getElementById('gif-progress-bar');
    const progressDiv = document.getElementById('gif-progress');
    progressDiv.style.display = 'block';
    progressBar.value = progress;
}

function displayVideo(url, type) {
    const container = document.getElementById('gif-container');
    if (!container) {
        console.error('Gif container not found');
        return;
    }

    container.innerHTML = '';

    if (type === 'gif') {
        const imgElement = document.createElement('img');
        imgElement.src = url;
        imgElement.alt = 'Animated GIF';
        imgElement.style.maxWidth = '100%';
        container.appendChild(imgElement);
    }

    const now = new Date();
    const fileName = `BitHabit-${formatDateTime(now)}.gif`;

    openGifInNewWindow(url, fileName);
    container.style.display = 'block';
    setTimeout(() => {
        container.scrollIntoView({behavior: 'smooth', block: 'start'});
    }, 100);
}

function openGifInNewWindow(url, fileName) {
    const newWindow = window.open('', '_blank');
    if (newWindow) {
        newWindow.document.write(`
            <html>
                <head>
                    <title>${fileName}</title>
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <style>
                        body { 
                            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; 
                            text-align: center; 
                            padding: 20px; 
                            background-color: #f0f0f0;
                            color: #333;
                        }
                        img { 
                            max-width: 100%; 
                            height: auto; 
                            margin-bottom: 20px;
                        }
                        .instructions { 
                            background-color: white;
                            padding: 15px;
                            border-radius: 10px;
                            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
                            text-align: left;
                        }
                    </style>
                </head>
                <body>
                    <img src="${url}" alt="생성된 GIF">
                    <div class="instructions">
                        <p><strong>1. 위에 움직이는 사진을 오래 누르고 "복사하기" 누르기</strong></p>
						<p><strong>2. 카톡에 붙여넣기</strong></p>
                    </div>
                </body>
            </html>
        `);
        newWindow.document.close();
    } else {
        alert('새 창을 열 수 없습니다. 브라우저 설정을 확인해 주세요.');
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