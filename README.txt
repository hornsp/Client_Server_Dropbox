How to Compile and Run the Server and Client Programs

Server:
* Compile: Not required as Perl is interpreted.
* Run: perl server.pl
* The server will start listening on a specified port (e.g., port 5000) and use SSL/TLS for secure communication.
* The server is running on stu.cs.jmu.edu.
* The server is configured to run on stu as specified by the project description.

Sync Helper:
* The sync_helper monitors and reports file changes (upload, download, delete) in real-time for clients sharing the same 
  user account.

How to Use:
* Ensure the server is running and users are authenticated.
* Start the sync helper by running:
    * python sync_helper.py
* Requires Python 3. Ensure the necessary Python modules (e.g., watchdog) are installed.

Functionality:
The sync helper detects changes made to files in the shared user directory across multiple clients and outputs a 
notification in the terminal for each change:
* File added: Triggered when a file is uploaded.
* File deleted: Triggered when a file is deleted.
* File downloaded: Triggered when a file is downloaded.
By running sync_helper.py alongside the client and server, users can observe all file activity in real-time, enabling better monitoring and collaboration across multiple devices.

Client:
* Compile: Not required as Perl is interpreted.
* Create a New User: perl client.pl stu.cs.jmu.edu <username> <password> CREATEUSER
* After logging in the user can then:
    * Upload a file: Enter a command: UPLOAD path\to\file
    * Download a File: Enter a command: DOWNLOAD <filename>
    * Delete a File: Enter a command: DELETE <filename>
    * Monitoring for Changes: I a user has multiple clients, each client will monitor for changes to the users' files

Authentication:
* Process: The client authenticates to the server using a username and password. Authentication is done over a secure 
* SSL/TLS connection.
* After login: Users can upload or download files from their own cloud storage directories on the server.

Access Control:
* Users are restricted to their own files; attempts to access other users' files result in an error message.

Concurrency:
* The server does not currently support multiple simultaneous client connections.

Error Handling:
* Basic error messages are implemented. Further improvements could include more informative feedback for a better user 
  experience.

Bugs:
