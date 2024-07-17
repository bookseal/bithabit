// attendance.js

export async function submitAttendance(id, startTime, duration) {
    validateId(id);
    const formData = prepareFormData(id, startTime, duration);
    
    try {
        await sendAttendanceData(formData);
        handleSuccessfulSubmission();
    } catch (error) {
        handleSubmissionError(error);
    }
}

function validateId(id) {
    if (!id) {
        alert("Please enter your id before starting.");
        throw new Error("ID is required");
    }
}

function prepareFormData(id, startTime, duration) {
    const formData = new URLSearchParams();
    formData.append('id', id);
    formData.append('in', startTime.toISOString());
    formData.append('duration', duration / 1000 / 60);
    formData.append('device', getDeviceInfo());
    formData.append('browser', getBrowserInfo());
    return formData;
}

function getDeviceInfo() {
    return navigator.platform || 'Unknown Device';
}

function getBrowserInfo() {
    const ua = navigator.userAgent;
    let browserName;
    if (ua.match(/chrome|chromium|crios/i)) browserName = "Chrome";
    else if (ua.match(/firefox|fxios/i)) browserName = "Firefox";
    else if (ua.match(/safari/i)) browserName = "Safari";
    else if (ua.match(/opr\//i)) browserName = "Opera";
    else if (ua.match(/edg/i)) browserName = "Edge";
    else browserName = "Unknown";
    return browserName;
}

async function sendAttendanceData(formData) {
    const response = await fetch(
        "https://script.google.com/macros/s/AKfycbz8xJpNZmECdex3fcykRQEyQ_UpHzYDe3vKl_nNGC1ELgA0JWzwLRbdaaCKuccZ4h8Lxg/exec",
        {
            method: "POST",
            body: formData.toString(),
            headers: {
                "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
            },
        }
    );

    console.log("Response: ", response);

    if (!response.ok) {
        throw new Error("Failed to submit attendance.");
    }

    const data = await response.json();
    console.log("Data: ", data);
}

function handleSuccessfulSubmission() {
    const captureBtn = document.getElementById("captureBtn");
    captureBtn.innerHTML = '<i class="fas fa-check"></i> 출석체크완료';
    captureBtn.classList.remove('btn-checking');
}

function handleSubmissionError(error) {
    console.error("Error: ", error);
    
    const errorMessageElement = document.getElementById("errorMessage");
    errorMessageElement.textContent = "An error occurred while submitting attendance.";
    errorMessageElement.style.display = "block";
    errorMessageElement.style.backgroundColor = "red";
    errorMessageElement.style.color = "white";

    const captureBtn = document.getElementById("captureBtn");
    captureBtn.innerHTML = '<i class="fas fa-camera"></i> Start';
    captureBtn.classList.remove('btn-checking');

    throw error; // Rethrow the error to be caught in toggleCapturing
}