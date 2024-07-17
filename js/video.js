// video.js

import { formatDateTime } from './utils.js';

export async function createAndDisplayVideo(capturedImages) {
    if (capturedImages.length === 0) {
        console.log("No captured images!");
        return;
    }

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
        const gif = createGIFObject(images[0]);
        try {
            addFramesToGIF(gif, images);
            setupGIFEvents(gif, resolve);
            gif.render();
            setupTimeout(reject);
        } catch (error) {
            console.error('Error during GIF creation:', error);
            reject(error);
        }
    });
}

function createGIFObject(firstImage) {
    return new GIF({
        workers: 2,
        quality: 1,
        width: firstImage.naturalWidth,
        height: firstImage.naturalHeight,
        workerScript: 'js/gif.worker.js',
        dither: false,
        colors: 64,
        createCanvas: createCanvas
    });
}

function createCanvas(width, height) {
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    canvas.getContext('2d', { willReadFrequently: true });
    return canvas;
}

function addFramesToGIF(gif, images) {
    if (images.length >= 1) {
        gif.addFrame(images[0], { delay: 1000 });
    }
    const framesToAdd = images.length >= 70 ? addReducedFrames : addAllFrames;
    framesToAdd(gif, images);
}

function addReducedFrames(gif, images) {
    for (let i = images.length - 1; i >= 0; i -= 2) {
        addFrame(gif, images[i], i, images.length);
    }
}

function addAllFrames(gif, images) {
    for (let i = images.length - 1; i >= 0; i--) {
        addFrame(gif, images[i], i, images.length);
    }
}

function addFrame(gif, image, index, totalFrames) {
    try {
        gif.addFrame(image, { delay: 200 });
    } catch (error) {
        console.error(`Error adding frame ${totalFrames - index}:`, error);
        throw error;
    }
}

function setupGIFEvents(gif, resolve) {
    gif.on('progress', (progress) => {
        updateProgressBar(progress);
    });

    gif.on('finished', (blob) => {
        resolve(blob);
    });
}

function setupTimeout(reject) {
    setTimeout(() => {
        reject(new Error('GIF creation timed out after 20 minutes'));
    }, 1200000); // 20 minute timeout
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

	const instruction = document.createElement('p');
	const isIphone = /iPhone|iPad|iPod/i.test(navigator.userAgent);
	const isChrome = /Chrome|CriOS/i.test(navigator.userAgent);
	let msg = '1. 위의 움직이는 사진을 오래 누르고';
	if (isIphone) {
		if (isChrome) {
			msg += '"포토에 저장"';
		}
		else {
			msg = '"사진 앱에 저장"';
		}
	else {
		
	}
	msg +=  '클릭<br>2. 카카오톡앱 실행 후 해당 오픈채팅방에 사진 전송';
	
	instruction.innerHTML = '<strong>1. 위에 움직이는 사진을 오래 누르고 "복사하기" 누르기</strong><br><strong>2. 공유버튼을 누르지 마시고 카톡앱을 실행하여 해당 오픈채팅방에 붙여넣기</strong>';
	container.appendChild(instruction);
	 container.style.display = 'block';
    setTimeout(() => {
        container.scrollIntoView({behavior: 'smooth', block: 'start'});
    }, 100);

	const now = new Date();
	const fileName = `BitHabit-${formatDateTime(now)}.gif`;
	const downloadButton = createButton(null, null, 'Download', 'btn-primary');
	downloadButton.addEventListener('click', () => downloadGif(url, fileName));
	container.appendChild(downloadButton);
}

function createButton(id, className, text, btnClassName) {
	const button = document.createElement('button');
	button.id = id;
	button.className = className;
	button.textContent = text;
	button.className = btnClassName;
	return button;
}

function downloadGif(url, fileName) {
	const a = document.createElement('a');
	a.href = url;
	a.download = fileName;
	document.body.appendChild(a);
	a.click();
	document.body.removeChild(a);
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