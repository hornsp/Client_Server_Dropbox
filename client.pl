#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::INET;

# Check for valid arguments
my ($host, $username, $password, $command) = @ARGV;
if (!$host || !$username || !$password || !$command) {
    die "Usage: perl client.pl <host> <username> <password> <command> [<file_path>]\n";
}

# Connect to the server
my $socket = IO::Socket::INET->new(
    PeerAddr => $host,
    PeerPort => 5000,
    Proto    => 'tcp'
) or die "Could not connect to server: $!";

# Handle the command
if ($command eq 'CREATEUSER') {
    print $socket "CREATE_USER $username $password\n";
    my $response = <$socket>;
    print $response;
    close $socket;
    exit;
}
elsif ($command eq 'LOGIN') {
    print $socket "LOGIN $username $password\n";
    my $response = <$socket>;
    if ($response =~ /LOGIN SUCCESS/) {
        print "Login successful. You can now enter commands.\n";
        while (1) {
            print "Enter command: ";
            my $user_command = <STDIN>;
            chomp $user_command;

            if (uc($user_command) eq 'EXIT') {
                print $socket "EXIT\n";
                print "Exiting the client. Goodbye!\n";
                close $socket;
                last;
            }

            # Handle file upload command separately
            if ($user_command =~ /^UPLOAD\s+(.+)/i) {
                my $file_path = $1;
                upload_file($socket, $file_path);
                next;
            }

            # Handle file download command seperately
            if ($user_command =~ /^DOWNLOAD\s+(.+)/i) {
                my $filename = $1;
                download_file($socket, $filename);
                next;
            }

            # Handle the DELETE command
            elsif ($user_command =~ /^DELETE\s+(.+)/i) {
                my $filename = $1;
                delete_file($socket, $filename);
                next;
            }

            # Send other commands to the server
            print $socket "$user_command\n";

            # Read and print response from server
            my $server_response = <$socket>;
            print $server_response;
        }
    } else {
        die "Login failed: $response\n";
    }
} 
elsif ($command eq 'UPLOAD') {
    my $file_path = $ARGV[4];
    upload_file($socket, $file_path);  # Call upload_file subroutine
} 
else {
    die "Invalid command. Supported commands: CREATEUSER, LOGIN, UPLOAD.\n";
}

close ($socket);

# Subroutine to handle file uploads
sub upload_file {
    my ($socket, $filename) = @_;
    if (-e $filename) {
        print $socket "UPLOAD $filename\n";
        open my $file, '<:raw', $filename or die "Could not open file for reading: $!\n";

        # Send file data to the server
        while (my $buffer = <$file>) {
            print $socket $buffer;
        }
        close $file;

        print $socket "EOF\n";  # Signal end of file
        my $response = <$socket>;
        print "Server response: $response\n";  # Print server response
    } else {
        print "File not found: $filename\n";
    }
}

# Subroutine for downloading a file
sub download_file {
    my ($socket, $filename) = @_;
    print $socket "DOWNLOAD $filename\n";

    my $response = <$socket>;
    chomp($response);
    if ($response eq 'DOWNLOAD SUCCESS') {
        open my $file, '>:raw', $filename or die "Could not open file for writing: $!\n";
        
        while (my $buffer = <$socket>) {
            last if $buffer eq "EOF\n";
            print $file $buffer;  # Write data to file
        }
        close $file;
        print "Downloaded file: $filename\n";
    } else {
        print "Download failed: $response\n";  # Print server error
    }
}

# Subroutine for deleting a file
sub delete_file {
    my ($socket, $filename) = @_;
    print $socket "DELETE $filename\n";

    my $response = <$socket>;
    print "Server response: $response";
}