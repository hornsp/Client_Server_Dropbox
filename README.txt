How to Compile and Run the server and client Programs

Server:
    * Compile: Not required as Perl is interpreter.
    * Run: perl server.pl
    * The server will start listening on a specified port (e.g., port 5000) and use SSL/TLS for secure communication.
    * The server is running on stu.cs.jmu.edu 
    * Server is currently running on stu as requested by the project description

Client:
    * Compile: Not required as Perl is interpreter.
    * Create a new user: perl client.pl stu.cs.jmu.edu <username> <password> CREATEUSER 
    * Uploading a file: perl client.pl stu.cs.jmu.edu <username> <password> UPLOAD <filename>
    * Downloading a file: perl client.pl stu.cs.jmu.edu <username> <password> DOWNLOAD <filename>
    * Deleting a file: perl client.pl stu.cs.jmu.edu <username> <password> DELETE <filename>
    * Monitoring for changes: perl client.pl stu.cs.jmu.edu <username> <password> MONITOR
        * Current bugs: Only displays the detected changes after the 'EXIT' command is invoked. 

Authentication:
    * Process:
        * The client authenticates to the server using a username and password. Authentication is conducted over a secure SSL/TLS connection.
        * After successful login, users can upload or download files from their own cloud storage directories on the server.
    * Access Control:
        * Users are restricted to their own files; attempts to access other users' files will result in an error message.* 

* Concurrency
    * The server does not currently support multiple simultaneous client connections.
* Error Handling:
    * Basic error messages are implemented; additional feedback could be provided for more informative user experience.