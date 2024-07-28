function getWeekNumber(d) {
    d = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
    var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    var weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    return weekNo;
}

function updateDateDisplay() {
    const today = new Date();
    const year = today.getFullYear();
    const month = today.getMonth() + 1;
    const date = today.getDate();
    const dayOfWeek = ['일', '월', '화', '수', '목', '금', '토'][today.getDay()];
    const weekNumber = getWeekNumber(today);

    const dateString = `${year}년 ${String(month).padStart(2, '0')}월 ${String(date).padStart(2, '0')}일 ${dayOfWeek}요일 ${weekNumber}주차`;

    const dateDisplay = document.getElementById('dateDisplay');
    if (dateDisplay) {
        dateDisplay.textContent = dateString;
    }
}

// Call these functions when the page loads
document.addEventListener('DOMContentLoaded', function() {
    updateDateDisplay();
});

// Update date display every minute to keep it current
setInterval(updateDateDisplay, 60000);