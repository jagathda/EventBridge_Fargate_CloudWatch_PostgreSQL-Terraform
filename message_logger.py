import json
import logging
import sys

# Configure logging to output to stdout
logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(asctime)s %(message)s')

def main():
    try:
        # Read the event from stdin
        raw_input = sys.stdin.read()
        if raw_input:
            logging.info(f"Raw input: {raw_input}")
            
            # Parse the raw input as JSON
            event = json.loads(raw_input)
            logging.info(f"Received event: {json.dumps(event, indent=4)}")
        else:
            logging.info("No input received")
    except json.JSONDecodeError as e:
        logging.error(f"Failed to decode JSON from stdin: {e}")
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")

if __name__ == '__main__':
    main()
