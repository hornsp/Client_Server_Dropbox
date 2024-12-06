#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;
use threads;

# # Thread for handling user commands
# my $user_input_thread = threads->create(\&handle_user_commands);

# # Main thread for synchronization
# sync_with_server();

# $user_input_thread->join();

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
        print "Login successful. Starting sync...\n";

        # Start sync thread
        my $sync_thread = threads->create(\&sync_with_server, $socket, $username);

        # User command loop
        while (1) {
            print "Enter a command: ";
            my $user_command = <STDIN>;
            chomp $user_command;

            last if uc($user_command) eq 'EXIT';
            handle_user_command($socket, $user_command);
        }

        $sync_thread->join();
    } else {
        die "Login failed: $response\n";
    }

} else {
    die "Invalid command. Supported commands: CREATEUSER, LOGIN, UPLOAD.\n";
}

close ($socket);

# Subroutine for user commands
sub handle_user_command {
    my ($socket, $command) = @_;
    if ($command =~ /^UPLOAD\s+(.+)/i) {
        upload_file($socket, $1);
    } elsif ($command =~ /^DOWNLOAD\s+(.+)/i) {
        download_file($socket, $1);
    } elsif ($command =~ /^DELETE\s+(.+)/i) {
        delete_file($socket, $1);
    } else {
        print $socket "$command\n";
        print <$socket>; # Print server response
    }
}

# Subroutine to handle file uploads
sub upload_file {
    my ($socket, $file_path) = @_;
    my $filename = (split /[\/\\]/, $file_path)[-1];

    open my $fh, '<:raw', $file_path or die "Cannot open file: $!";
    my $filesize = -s $file_path;

    # Send command
    print $socket "UPLOAD $filename $filesize\n";

    # Check server response
    my $response = <$socket>;
    die "Server error: $response" unless $response =~ /READY/;

    # Send file contents
    while (read($fh, my $buffer, 1024)) {
        print $socket $buffer;
    }
    close $fh;

    # Confirm upload success
    $response = <$socket>;
    print "Server response: $response";
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

# Sync function to detect and propagate changes
sub sync_with_server {
    my ($socket, $username) = @_;
    while (1) {
        print $socket "SYNC\n";
        while (my $response = <$socket>) {
            last if $response eq "SYNC END\n";
            if ($response =~ /^UPLOAD (.+)/) {
                my $file = $1;
                download_file($socket, $file);
            } elsif ($response =~ /^DELETE (.+)/) {
                my $file = $1;
                unlink "uploads/$file" if -e "uploads/$file";
            }
        }
        sleep(5);
    }
}
# sub sync_with_server {
#     my ($socket, $username) = @_;
#     my %local_state;

#     while (1) {
#         # Scan uploads folder
#         my $uploads_dir = 'uploads';
#         opendir my $dh, $uploads_dir or die "Could not open uploads directory: $!";
#         my @files = readdir $dh;
#         closedir $dh;

#         foreach my $file (@files) {
#             next if $file =~ /^\./;  # Skip hidden files and special entries (., ..)
#             my $path = "$uploads_dir/$file";
#             my @stats = stat($path);
#             my $mod_time = $stats[9];
#             my $file_size = $stats[7];

#             # If the file is new or modified (check both mod time and size)
#             if (!exists $local_state{$file} || $local_state{$file}{mod_time} != $mod_time || $local_state{$file}{size} != $file_size) {
#                 upload_file($socket, $path);
#                 $local_state{$file} = { mod_time => $mod_time, size => $file_size };
#             }
#         }

#         # Check for deleted files
#         foreach my $file (keys %local_state) {
#             unless (-e "$uploads_dir/$file") {
#                 delete_file($socket, $file);
#                 delete $local_state{$file};
#             }
#         }

#         # Query server for updates
#         print $socket "SYNC\n";
#         while (my $server_response = <$socket>) {
#             last if $server_response eq "SYNC END\n";

#             if ($server_response =~ /^UPLOAD\s+(.+)/) {
#                 my $filename = $1;
#                 download_file($socket, $filename) unless -e "$uploads_dir/$filename";
#             }
#             elsif ($server_response =~ /^DELETE\s+(.+)/) {
#                 my $filename = $1;
#                 unlink "$uploads_dir/$filename" if -e "$uploads_dir/$filename";
#             }
#         }

#         sleep 5;  # Wait before next sync
#     }
# }

sub debug_log {
    my $message = shift;
    open my $log, '>>', 'client.log' or die "Cannot open log file: $!";
    print $log "$message\n";
    close $log;
}

sub handle_user_commands {
    while (1) {
        print "Enter a command: ";
        my $command = <STDIN>;
        chomp($command);
        last if $command eq 'EXIT';  # Allow the user to exit
        send_command_to_server($command);
    }
}