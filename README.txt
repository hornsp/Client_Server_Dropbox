How to Compile and Run the Server and Client Programs

Server:
* Compile: Not required as Perl is interpreted.
* Run: perl server.pl
* The server will start listening on a specified port (e.g., port 5000) and use SSL/TLS for secure communication.
* The server is running on stu.cs.jmu.edu.
* The server is configured to run on stu as specified by the project description.

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