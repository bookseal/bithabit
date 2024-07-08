// attendance.js

export async function submitAttendance(id, startTime, duration) {
	const errorMessageElement = document.getElementById("errorMessage");
	const captureBtn = document.getElementById("captureBtn");

    errorMessageElement.textContent = "";
    errorMessageElement.style.display = "none";

	captureBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> 출석체크 중...';
    captureBtn.classList.add('btn-checking');  // Add the new class

    if (!id) {
        alert("Please enter your id before starting.");
		throw new Error("ID is required");
    }

    const formData = new URLSearchParams();
	const current_time = new Date();
    formData.append('id', id);
	formData.append('in', startTime.toISOString());
	formData.append('duration', duration / 1000 / 60);

    try {
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

        console.log("Response: ", response); // Log the response

        if (response.ok) {
            const data = await response.json();
            console.log("Data: ", data); // Log the data received
        } else {
			captureBtn.innerHTML = '<i class="fas fa-camera"></i> Start';
			captureBtn.classList.remove('btn-checking');
            throw new Error("Failed to submit attendance.");
        }
    } catch (error) {
        console.error("Error: ", error); // Log the error
        errorMessageElement.textContent = "An error occurred while submitting attendance.";
        errorMessageElement.style.display = "block";
        errorMessageElement.style.backgroundColor = "red";
        errorMessageElement.style.color = "white";
		captureBtn.innerHTML = '<i class="fas fa-camera"></i> Start';
		captureBtn.classList.remove('btn-checking');
        throw error; // Rethrow the error to be caught in toggleCapturing
    }
}
