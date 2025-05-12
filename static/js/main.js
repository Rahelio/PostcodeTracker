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
    
    // Location status elements
    const locationStatusContainer = document.getElementById('location-status');
    const startLocatingBtn = document.getElementById('start-locating-btn');
    const endLocatingBtn = document.getElementById('end-locating-btn');
    
    // Alert elements
    const alertContainer = document.getElementById('alert-container');
    
    // Check if a journey is already in progress on page load
    checkActiveJourney();
    
    // Start journey with current location
    if (startJourneyForm) {
        startJourneyForm.addEventListener('submit', function(e) {
            e.preventDefault();
            getCurrentLocation('start');
        });
    }
    
    // End journey with current location
    if (endJourneyForm) {
        endJourneyForm.addEventListener('submit', function(e) {
            e.preventDefault();
            getCurrentLocation('end');
        });
    }
    
    // Get current location and then convert to postcode
    function getCurrentLocation(action) {
        if (!navigator.geolocation) {
            showAlert('Geolocation is not supported by your browser', 'danger');
            return;
        }
        
        const statusElement = action === 'start' ? startLocatingBtn : endLocatingBtn;
        const originalText = statusElement.innerHTML;
        
        // Update button to show loading state
        statusElement.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i>Getting location...';
        statusElement.disabled = true;
        
        navigator.geolocation.getCurrentPosition(
            // Success callback
            function(position) {
                const latitude = position.coords.latitude;
                const longitude = position.coords.longitude;
                
                // Convert coordinates to UK postcode
                convertCoordsToPostcode(latitude, longitude, action);
            },
            // Error callback
            function(error) {
                // Restore the button text from data attribute
                const buttonText = statusElement.getAttribute('data-original-text');
                statusElement.innerHTML = buttonText;
                statusElement.disabled = false;
                
                let errorMessage = 'Unable to retrieve your location';
                switch(error.code) {
                    case error.PERMISSION_DENIED:
                        errorMessage = 'Location permission denied. Please allow location access and try again.';
                        break;
                    case error.POSITION_UNAVAILABLE:
                        errorMessage = 'Location information is unavailable. Please try again.';
                        break;
                    case error.TIMEOUT:
                        errorMessage = 'Location request timed out. Please try again.';
                        break;
                }
                showAlert(errorMessage, 'danger');
            },
            // Options
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            }
        );
    }
    
    // Convert coordinates to UK postcode using our server endpoint
    function convertCoordsToPostcode(latitude, longitude, action) {
        const statusElement = action === 'start' ? startLocatingBtn : endLocatingBtn;
        const originalText = statusElement.getAttribute('data-original-text');
        
        // Use our server API to convert coordinates
        fetch('/api/postcode/from-coordinates', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ 
                latitude: latitude, 
                longitude: longitude 
            })
        })
        .then(response => response.json())
        .then(data => {
            statusElement.innerHTML = originalText;
            statusElement.disabled = false;
            
            if (data.success && data.postcode) {
                const postcode = data.postcode;
                
                // Show user what postcode was detected
                showAlert(`Detected postcode: ${formatPostcode(postcode)}`, 'info');
                
                if (action === 'start') {
                    startJourney(postcode);
                } else {
                    endJourney(postcode);
                }
            } else {
                showAlert(data.message || 'Could not find a UK postcode for your current location', 'warning');
            }
        })
        .catch(error => {
            statusElement.innerHTML = originalText;
            statusElement.disabled = false;
            showAlert('Error converting location to postcode: ' + error.message, 'danger');
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
