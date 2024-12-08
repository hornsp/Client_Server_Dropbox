use strict;
use warnings;
use IO::Socket::INET;
use Digest::SHA qw(sha256_hex);
use File::Basename qw(basename);
use IO::Socket::SSL;
use Config;
use threads;

my $ownership_file = 'file_owners.txt';
my $users_file = 'users.txt';
my %file_owners;
my $username;
my $SYNC_HELPER_HOST = '127.0.0.1';  # Sync helper is on the same machine
my $SYNC_HELPER_PORT = 9000;         # Sync helper listens on this port

# Load file ownership on server startup
load_file_ownership();

# Create a listening socket
my $server = IO::Socket::INET->new(
    LocalPort => 5000,
    Proto     => 'tcp',
    Listen    => 10,
    Reuse     => 1
) or die "Could not create server socket: $!";

$| = 1; # Enable autoflush

print "Server waiting for client connections...\n";

# Main server loop to accept connections
while (my $client = $server->accept()) {
    threads->create(\&handle_client, $client);
}

# Handle individual client
sub handle_client {
    my ($client) = @_;
    
    while (my $command = <$client>) {
        chomp $command;
        print "Received command: $command\n";

        if ($command =~ /^CREATE_USER (\S+) (\S+)$/) {
            my ($username, $password) = ($1, $2);
            create_user($username, $password, $client);
        }
        elsif ($command =~ /^LOGIN (\S+) (\S+)$/) {
            my ($username_input, $password) = ($1, $2);
            if (authenticate_user($username_input, $password)) {
                $username = $username_input;
                print "Login successful for $username\n";
                print $client "LOGIN SUCCESS\n";
            } else {
                print $client "LOGIN FAILURE\n";
            }
        }
        elsif ($command =~ /^UPLOAD\s+(.+)$/) {
            my $file_path = $1;
            handle_upload($client, $username, $file_path);
        }
        elsif ($command =~ /^DOWNLOAD\s+(.+)$/) {
            my $filename = $1;
            handle_download($client, $username, $filename);
        }
        elsif ($command =~ /^DELETE\s+(.+)$/) {
            my $filename = $1;
            handle_delete($client, $username, $filename);
        }
    }
    
    close $client;
}

# Handle user creation
sub create_user {
    my ($username, $password, $client_socket) = @_;
    my $hashed_password = sha256_hex($password);

    open my $fh, '>>', $users_file or die "Could not open users file: $!\n";
    print $fh "$username:$hashed_password\n";
    close $fh;

    print $client_socket "User '$username' created successfully.\n";
}

# Helper function to authenticate user
sub authenticate_user {
    my ($username, $password) = @_;
    open my $fh, '<', $users_file or die "Could not open users file: $!";
    while (my $line = <$fh>) {
        chomp $line;
        my ($stored_user, $stored_pass) = split /:/, $line;
        if ($username eq $stored_user && sha256_hex($password) eq $stored_pass) {
            return 1;
        }
    }
    close $fh;
    return 0;
}

# Handle file upload
sub handle_upload {
    my ($client_socket, $username, $filepath) = @_;
    
    my $storage_dir = 'uploads';
    mkdir $storage_dir unless -d $storage_dir;  # Ensure uploads directory exists

    my $file_name = basename($filepath);
    my $target_path = "$storage_dir/$file_name";

    print $client_socket "READY_TO_RECEIVE\n";  # Notify the client

    open my $file, '>:raw', $target_path or do {
        print $client_socket "ERROR: Unable to open file $target_path for writing.\n";
        return;  # Skip further processing if file cannot be opened
    };

    # Receive and write file data
    while (my $buffer = <$client_socket>) {
        last if $buffer =~ /EOF/;  # Stop on end-of-file marker
        print $file $buffer;
    }
    close $file;

    # Lock the ownership file to prevent race conditions
    flock_file($ownership_file);

    # Log ownership of the uploaded file
    $file_owners{$file_name} = $username;
    save_file_ownership();

    # Unlock after operation
    unlock_file($ownership_file);

    print $client_socket "UPLOAD SUCCESS\n";
    notify_sync_helper("UPLOAD", $file_name, $username);
}

# Handle file download
sub handle_download {
    my ($client_socket, $username, $filepath) = @_;
    my $filename = basename($filepath);
    my $full_path = "uploads/$filename";

    load_file_ownership();

    if (-e $full_path && $file_owners{$filename} && $file_owners{$filename} eq $username) {
        print $client_socket "DOWNLOAD SUCCESS\n";
        open my $file, '<:raw', $full_path or do {
            print $client_socket "ERROR: Could not open file for reading\n";
            return;
        };
        while (my $bytes = read($file, my $buffer, 1024)) {
            print $client_socket $buffer;
        }
        close $file;
        print $client_socket "EOF\n";

        print "File '$filename' sent to client.\n";
        notify_sync_helper("DOWNLOAD", $filename, $username);
    } elsif (!-e $full_path) {
        print $client_socket "ERROR: File not found\n";
    } else {
        print $client_socket "ERROR: Permission denied\n";
    }
}

# Handle file deletion
sub handle_delete {
    my ($client_socket, $username, $filename) = @_;
    my $file_path = "uploads/" . basename($filename);

    load_file_ownership();

    if (-e $file_path && $file_owners{$filename} eq $username) {
        unlink $file_path or do {
            print $client_socket "ERROR: Could not delete file '$filename'.\n";
            return;
        };

        delete $file_owners{$filename};
        save_file_ownership();

        print $client_socket "DELETE SUCCESS: File '$filename' has been deleted.\n";
        notify_sync_helper("DELETE", $filename, $username);
    } else {
        print $client_socket "ERROR: File not found or permission denied.\n";
    }
}

# Load file ownership data
sub load_file_ownership {
    # Lock the ownership file to prevent race conditions
    flock_file($ownership_file);

    %file_owners = (); # Clear existing data to avoid stale entries
    if (-e $ownership_file) {
        open my $fh, '<', $ownership_file or die "Could not open ownership file: $!";
        while (<$fh>) {
            chomp;
            my ($filename, $owner) = split /:/;
            $file_owners{$filename} = $owner;
        }
        close $fh;
    }

    unlock_file($ownership_file);
}

# Save file ownership data
sub save_file_ownership {
    # Lock the ownership file to prevent race conditions
    flock_file($ownership_file);

    open my $fh, '>', $ownership_file or die "Could not open ownership file\n";
    foreach my $filename (keys %file_owners) {
        print $fh "$filename:$file_owners{$filename}\n";
    }
    close $fh;

    unlock_file($ownership_file);
}

# Lock a file using flock
sub flock_file {
    my ($filename) = @_;
    open my $fh, '+<', $filename or die "Could not open file $filename for locking: $!";
    flock($fh, 2) or die "Could not lock file $filename: $!";  # Lock the file for reading and writing
    return $fh;
}

# Unlock a file
sub unlock_file {
    my ($filename) = @_;
    
    # Skip unlocking on Windows
    if ($^O eq 'MSWin32') {
        return;  # No unlock operation needed for Windows
    }
    
    open my $fh, '+<', $filename or die "Could not open file $filename for unlocking: $!";
    flock($fh, 8) or die "Could not unlock file $filename: $!";  # Unlock the file
    close $fh;
}

sub notify_sync_helper {
    my ($action, $filename, $username) = @_;

    # Create a socket connection to sync_helper
    my $socket = IO::Socket::INET->new(
        PeerHost => $SYNC_HELPER_HOST,
        PeerPort => $SYNC_HELPER_PORT,
        Proto    => 'tcp',
    ) or die "Could not connect to sync_helper: $!\n";

    # Create the message in the format: Action|Filename|Username
    my $message = "$action|$filename|$username";

    # Send the message to the sync helper
    $socket->send($message) or die "Send failed: $!\n";
    $socket->close();
    print "Sent notification to sync_helper: $message\n";
}