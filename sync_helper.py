import os
import time
import socket
import subprocess

# Configuration
MONITOR_FOLDER = "C:\Users\samue\Desktop\CS-610\Project4_Horn\uploads"
SERVER_HOST = "localhost" 
SERVER_PORT = 5000  
SCAN_INTERVAL = 5  # Time in seconds between folder scans

# Function to get a snapshot of the folder
def get_folder_snapshot(folder):
    snapshot = {}
    for root, _, files in os.walk(folder):
        for file in files:
            path = os.path.join(root, file)
            snapshot[path] = os.stat(path).st_mtime
    return snapshot

# Function to communicate with the server
def send_to_server(command, filename):
    try:
        subprocess.run(
            ["perl", "perl_client.pl", command, filename],
            check=True
        )
        print(f"Sent to Perl client: {command} {filename}")
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
                send_to_server("UPLOAD", os.path.relpath(path, MONITOR_FOLDER))
            elif mtime != previous_snapshot[path]:
                print(f"File modified: {path}")
                send_to_server("UPLOAD", os.path.relpath(path, MONITOR_FOLDER))

        # Check for deleted files
        for path in previous_snapshot:
            if path not in current_snapshot:
                print(f"File deleted: {path}")
                send_to_server("DELETE", os.path.relpath(path, MONITOR_FOLDER))

        previous_snapshot = current_snapshot

if __name__ == "__main__":
    monitor_folder()
