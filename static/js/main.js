document.addEventListener('DOMContentLoaded', function() {
    // Elements for journey control
    const startJourneyForm = document.getElementById('start-journey-form');
    const endJourneyForm = document.getElementById('end-journey-form');
    const activeJourneyPanel = document.getElementById('active-journey-panel');
    const completedJourneyPanel = document.getElementById('completed-journey-panel');
    
    // Journey status elements
    const journeyStatus = document.getElementById('journey-status');
    const startPostcodeDisplay = document.getElementById('start-postcode-display');
    const journeyStartTimeDisplay = document.getElementById('journey-start-time');
    
    // Journey result elements
    const journeyResultContainer = document.getElementById('journey-result-container');
    const startPostcodeResult = document.getElementById('start-postcode-result');
    const endPostcodeResult = document.getElementById('end-postcode-result');
    const distanceResult = document.getElementById('distance-result');
    
    // Alert elements
    const alertContainer = document.getElementById('alert-container');
    
    // Check if a journey is already in progress on page load
    checkActiveJourney();
    
    // Start journey form submission
    if (startJourneyForm) {
        startJourneyForm.addEventListener('submit', function(e) {
            e.preventDefault();
            
            const startPostcode = document.getElementById('start-postcode').value.trim();
            if (!startPostcode) {
                showAlert('Please enter a start postcode', 'danger');
                return;
            }
            
            startJourney(startPostcode);
        });
    }
    
    // End journey form submission
    if (endJourneyForm) {
        endJourneyForm.addEventListener('submit', function(e) {
            e.preventDefault();
            
            const endPostcode = document.getElementById('end-postcode').value.trim();
            if (!endPostcode) {
                showAlert('Please enter an end postcode', 'danger');
                return;
            }
            
            endJourney(endPostcode);
        });
    }
    
    // Function to check if there's an active journey
    function checkActiveJourney() {
        fetch('/api/journey/active')
            .then(response => response.json())
            .then(data => {
                if (data.success && data.active) {
                    displayActiveJourney(data.journey);
                } else {
                    hideActiveJourney();
                }
            })
            .catch(error => {
                console.error('Error checking active journey:', error);
                showAlert('Error checking journey status: ' + error.message, 'danger');
            });
    }
    
    // Function to start a new journey
    function startJourney(startPostcode) {
        fetch('/api/journey/start', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ start_postcode: startPostcode })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayActiveJourney(data.journey);
                showAlert('Journey started successfully!', 'success');
                document.getElementById('start-postcode').value = '';
            } else {
                showAlert(data.message, 'danger');
            }
        })
        .catch(error => {
            console.error('Error starting journey:', error);
            showAlert('Error starting journey: ' + error.message, 'danger');
        });
    }
    
    // Function to end an active journey
    function endJourney(endPostcode) {
        fetch('/api/journey/end', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ end_postcode: endPostcode })
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                hideActiveJourney();
                displayCompletedJourney(data.journey);
                showAlert('Journey completed successfully!', 'success');
                document.getElementById('end-postcode').value = '';
            } else {
                showAlert(data.message, 'danger');
            }
        })
        .catch(error => {
            console.error('Error ending journey:', error);
            showAlert('Error ending journey: ' + error.message, 'danger');
        });
    }
    
    // Function to display active journey
    function displayActiveJourney(journey) {
        if (startJourneyForm) startJourneyForm.classList.add('d-none');
        if (activeJourneyPanel) {
            activeJourneyPanel.classList.remove('d-none');
            
            if (startPostcodeDisplay) {
                startPostcodeDisplay.textContent = formatPostcode(journey.start_postcode);
            }
            
            if (journeyStartTimeDisplay) {
                const startDate = new Date(journey.start_time);
                journeyStartTimeDisplay.textContent = startDate.toLocaleString();
            }
        }
        
        // Hide completed journey panel if visible
        if (completedJourneyPanel) {
            completedJourneyPanel.classList.add('d-none');
        }
    }
    
    // Function to hide active journey
    function hideActiveJourney() {
        if (startJourneyForm) startJourneyForm.classList.remove('d-none');
        if (activeJourneyPanel) activeJourneyPanel.classList.add('d-none');
    }
    
    // Function to display completed journey
    function displayCompletedJourney(journey) {
        if (completedJourneyPanel) {
            completedJourneyPanel.classList.remove('d-none');
            
            if (startPostcodeResult) {
                startPostcodeResult.textContent = formatPostcode(journey.start_postcode);
            }
            
            if (endPostcodeResult) {
                endPostcodeResult.textContent = formatPostcode(journey.end_postcode);
            }
            
            if (distanceResult) {
                distanceResult.textContent = journey.distance_miles;
            }
        }
    }
    
    // Function to show alerts
    function showAlert(message, type) {
        if (!alertContainer) return;
        
        // Create alert element
        const alert = document.createElement('div');
        alert.className = `alert alert-${type} alert-dismissible fade show`;
        alert.role = 'alert';
        alert.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        `;
        
        // Add to container
        alertContainer.appendChild(alert);
        
        // Auto remove after 5 seconds
        setTimeout(() => {
            if (alert.parentNode === alertContainer) {
                alertContainer.removeChild(alert);
            }
        }, 5000);
    }
    
    // Helper function to format postcodes with a space
    function formatPostcode(postcode) {
        if (!postcode) return '';
        
        // Format UK postcode to have a space in the correct place
        // e.g. "SW1A1AA" -> "SW1A 1AA"
        postcode = postcode.toUpperCase().trim().replace(/\s+/g, '');
        const length = postcode.length;
        
        if (length <= 3) return postcode;
        return postcode.slice(0, -3) + ' ' + postcode.slice(-3);
    }
});
