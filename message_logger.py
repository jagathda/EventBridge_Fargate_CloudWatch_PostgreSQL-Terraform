import json
import logging
import sys

#Configure logging
logging.basicConfig(filename='/tmp/message.log', level=logging.INFO, format='%(asctime)s %(message)s')

def handle_event(event):
    #Log the event
    logging.info(f"Received event: {json.dumps(event)}")

def main():
    #Read the event from stdin
    event = json.load(sys.stdin)
    handle_event(event)

if _name_ == '_main_':
    main()