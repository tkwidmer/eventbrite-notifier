#!/bin/bash

# Eventbrite Ticket Monitor Script
# Monitors an Eventbrite event for ticket availability every minute

# Load configuration from config file
CONFIG_FILE="config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file 'config' not found!"
    echo "Please copy 'config.sample' to 'config' and update the values:"
    echo "  cp config.sample config"
    echo "  # Edit config file with your EVENT_ID and API_TOKEN"
    exit 1
fi

# Source the configuration file
source "$CONFIG_FILE"

# Validate required configuration
if [ -z "$EVENT_ID" ] || [ "$EVENT_ID" = "YOUR_EVENT_ID_HERE" ]; then
    echo "❌ EVENT_ID not configured. Please update the 'config' file."
    exit 1
fi

if [ -z "$API_TOKEN" ] || [ "$API_TOKEN" = "YOUR_API_TOKEN_HERE" ]; then
    echo "❌ API_TOKEN not configured. Please update the 'config' file."
    exit 1
fi

# Set defaults if not specified in config
CHECK_INTERVAL=${CHECK_INTERVAL:-60}
LOG_FILE="eventbrite_monitor.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to send system notification (macOS)
send_notification() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\""
}

# Function to check ticket availability
check_tickets() {
    local response=$(curl -s -X GET \
        "https://www.eventbriteapi.com/v3/events/${EVENT_ID}/?expand=ticket_availability" \
        -H "Authorization: Bearer ${API_TOKEN}")
    
    # Check if curl was successful
    if [ $? -ne 0 ]; then
        log_message "ERROR: Failed to connect to Eventbrite API"
        return 1
    fi
    
    # Check for API errors
    if echo "$response" | grep -q '"error"'; then
        local error_msg=$(echo "$response" | grep -o '"error_description":"[^"]*"' | cut -d'"' -f4)
        log_message "API ERROR: $error_msg"
        return 1
    fi
    
    # Parse ticket availability
    local tickets_available=$(echo "$response" | grep -o '"has_available_tickets":[^,}]*' | cut -d':' -f2 | tr -d ' ')
    local event_name=$(echo "$response" | sed -n 's/.*"name":{"text":"\([^"]*\)".*/\1/p')
    local is_sold_out=$(echo "$response" | grep -o '"is_sold_out":[^,}]*' | cut -d':' -f2 | tr -d ' ')
    
    if [ -z "$tickets_available" ]; then
        log_message "WARNING: Could not parse ticket availability from response"
        return 1
    fi
    
    echo "$tickets_available|$event_name|$is_sold_out"
    return 0
}

# Main monitoring loop
main() {
    echo -e "${GREEN}Starting Eventbrite Ticket Monitor${NC}"
    echo -e "Event ID: ${EVENT_ID}"
    echo -e "Check interval: ${CHECK_INTERVAL} seconds"
    echo -e "Log file: ${LOG_FILE}"
    echo -e "Press Ctrl+C to stop\n"
    
    log_message "Monitor started for event ID: $EVENT_ID"
    
    local last_status=""
    local consecutive_errors=0
    
    while true; do
        result=$(check_tickets)
        
        if [ $? -eq 0 ]; then
            consecutive_errors=0
            IFS='|' read -r tickets_available event_name is_sold_out <<< "$result"
            
            if [ "$tickets_available" = "true" ]; then
                if [ "$last_status" != "available" ]; then
                    echo -e "${GREEN}🎉 TICKETS AVAILABLE!${NC}"
                    log_message "ALERT: Tickets are now available for: $event_name"
                    send_notification "Eventbrite Alert" "Tickets available for: $event_name"
                    last_status="available"
                else
                    echo -e "${GREEN}✓ Tickets still available${NC}"
                fi
            else
                local status_msg="No tickets available"
                if [ "$is_sold_out" = "true" ]; then
                    status_msg="Event is sold out"
                fi
                
                if [ "$last_status" != "unavailable" ]; then
                    echo -e "${YELLOW}⏳ $status_msg${NC}"
                    log_message "INFO: $status_msg for: $event_name"
                    last_status="unavailable"
                else
                    echo -e "${YELLOW}⏳ Still $status_msg${NC}"
                fi
            fi
        else
            consecutive_errors=$((consecutive_errors + 1))
            echo -e "${RED}❌ Error checking tickets (attempt $consecutive_errors)${NC}"
            
            if [ $consecutive_errors -ge 5 ]; then
                log_message "ERROR: Too many consecutive errors. Stopping monitor."
                send_notification "Eventbrite Monitor Error" "Monitor stopped due to repeated errors"
                exit 1
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Monitor stopped by user${NC}"; log_message "Monitor stopped by user"; exit 0' INT

# Start the monitor
main