import os
import time
import subprocess
import socket

# Configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVER_HOST = "localhost"
MONITOR_FOLDER = os.path.join(SCRIPT_DIR, "uploads")  # Adjust path relative to script location
SCAN_INTERVAL = 5  # Time in seconds between folder scans
CREDENTIALS_FILE = "users.txt"  # Configuration file with usernames and hashed passwords

def start_sync_helper(port):
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind(('127.0.0.1', port))
    server_socket.listen(5)
    print(f"Sync helper listening on port {port}...")

    while True:
        client_socket, addr = server_socket.accept()
        print(f"Connection received from {addr}")

        message = client_socket.recv(1024).decode('utf-8').strip()
        if message:
            handle_notification(message)
        client_socket.close()

def handle_notification(message):
    # Message format: Action|Filename|Username
    parts = message.split('|')
    if len(parts) == 3:
        action, filename, username = parts
        if action == "UPLOAD":
            print(f"File added: {filename} by {username}")
        elif action == "DOWNLOAD":
            print(f"File downloaded: {filename} by {username}")
        elif action == "DELETE":
            print(f"File deleted: {filename} by {username}")
        else:
            print(f"Unknown action: {message}")
    else:
        print(f"Invalid notification message: {message}")

# Function to get a snapshot of the folder
def get_folder_snapshot(folder):
    snapshot = {}
    for root, _, files in os.walk(folder):
        for file in files:
            path = os.path.join(root, file)
            snapshot[path] = os.stat(path).st_mtime
    return snapshot

# Function to read credentials from the users.txt file
def read_credentials():
    credentials = {}
    try:
        with open(CREDENTIALS_FILE, 'r') as file:
            for line in file:
                username, hashed_password = line.strip().split(":")
                credentials[username] = hashed_password
    except FileNotFoundError:
        print(f"Error: The configuration file '{CREDENTIALS_FILE}' was not found.")
    except Exception as e:
        print(f"Error reading credentials: {e}")
    return credentials

# Function to communicate with the server
def send_to_server(command, filename):
    credentials = read_credentials()
    if not credentials:
        print("No credentials found. Cannot proceed.")
        return

    # Select the first available username and password (you can modify this to choose dynamically)
    username, hashed_password = list(credentials.items())[0]  # Get the first username/password pair

    # Get the relative path of the file from the MONITOR_FOLDER
    rel_filename = os.path.relpath(filename, MONITOR_FOLDER)

    try:
        # Make sure the path to the Perl client is correct
        script_path = os.path.join(os.path.dirname(__file__), 'client.pl')

        # Send LOGIN first
        subprocess.run(
            ["perl", script_path, SERVER_HOST, username, hashed_password, "LOGIN"],
            check=True
        )
        print(f"Login successful for {username}")

        if command == "UPLOAD":
            subprocess.run(
                ["perl", script_path, SERVER_HOST, username, hashed_password, "UPLOAD", rel_filename],
                check=True
            )
            print(f"Sent to Perl client: UPLOAD {rel_filename}")
            print(f"File uploaded: {rel_filename}")
        elif command == "DOWNLOAD":
            subprocess.run(
                ["perl", script_path, SERVER_HOST, username, hashed_password, "DOWNLOAD", rel_filename],
                check=True
            )
            print(f"Sent to Perl client: DOWNLOAD {rel_filename}")
            print(f"File downloaded: {rel_filename}")
        elif command == "DELETE":
            subprocess.run(
                ["perl", script_path, SERVER_HOST, username, hashed_password, "DELETE", rel_filename],
                check=True
            )
            print(f"Sent to Perl client: DELETE {rel_filename}")
            print(f"File deleted: {rel_filename}")

    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")

# Main function
def monitor_folder():
    previous_snapshot = get_folder_snapshot(MONITOR_FOLDER)

    while True:
        time.sleep(SCAN_INTERVAL)
        current_snapshot = get_folder_snapshot(MONITOR_FOLDER)

        # Check for added/modified files
        for path, mtime in current_snapshot.items():
            if path not in previous_snapshot:
                print(f"File added: {path}")
                send_to_server("UPLOAD", path)
            elif mtime != previous_snapshot[path]:
                print(f"File modified: {path}")
                send_to_server("UPLOAD", path)

        # Check for deleted files
        for path in previous_snapshot:
            if path not in current_snapshot:
                print(f"File deleted: {path}")
                send_to_server("DELETE", path)

        previous_snapshot = current_snapshot

if __name__ == "__main__":
    SYNC_HELPER_PORT = 9000
    start_sync_helper(SYNC_HELPER_PORT)
