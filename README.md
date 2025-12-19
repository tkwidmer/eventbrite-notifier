# Eventbrite Ticket Monitor

A bash script that monitors an Eventbrite event for ticket availability and sends notifications when tickets become available.

## Setup

1. **Copy the sample configuration file:**
   ```bash
   cp config.sample config
   ```

2. **Edit the configuration file:**
   ```bash
   nano config
   ```
   
   Update the following values:
   - `EVENT_ID`: Your Eventbrite event ID (found in the event URL)
   - `API_TOKEN`: Your Eventbrite API token (get from https://www.eventbrite.com/platform/api-keys)
   - `CHECK_INTERVAL`: How often to check in seconds (default: 60)

3. **Make the script executable:**
   ```bash
   chmod +x eventbrite_monitor.sh
   ```

## Usage

Run the monitor:
```bash
./eventbrite_monitor.sh
```

The script will:
- Check for tickets every minute (or your configured interval)
- Display colored status updates in the terminal
- Send macOS notifications when tickets become available
- Log all activity to `eventbrite_monitor.log`

## Stopping the Monitor

- Press `Ctrl+C` to stop the script
- Or if running in background: `kill [process_id]`

## Running in Background

To run the script in the background:
```bash
./eventbrite_monitor.sh &
```

To keep it running even after closing the terminal:
```bash
nohup ./eventbrite_monitor.sh &
```

## Getting Your API Token

1. Go to https://www.eventbrite.com/platform/api-keys
2. Log in to your Eventbrite account
3. Create a new API key
4. Copy the token to your `config` file

## Finding Your Event ID

The event ID is the number at the end of your Eventbrite event URL:
```
https://www.eventbrite.com/e/event-name-1965643083376
                                              ^^^^^^^^^^^^
                                              This is your EVENT_ID
```