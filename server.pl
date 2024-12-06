use strict;
use warnings;
use IO::Socket::INET;
use Digest::SHA qw(sha256_hex);
use JSON;
use File::Basename qw(basename);
use threads;

my $ownership_file = 'file_owners.txt';
my $users_file = 'users.txt';
my %file_owners;
my %user_events;
my %monitoring_clients;
my $username;

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

while (my $client = $server->accept()) {
    while (my $command = <$client>) {
        chomp $command;
        print "Received command: $command\n";

        if ($command =~ /^CREATE_USER (\S+) (\S+)$/) {
            my ($username, $password) = ($1, $2);
            create_user($username, $password, $client); # Pass $client
        }
        elsif ($command =~ /^LOGIN (\S+) (\S+)$/) {
            my ($username_input, $password) = ($1, $2);
            if (authenticate_user($username_input, $password)) {
                $username = $username_input;  # Set global username after successful login
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

# Helper funciton to authenticate user
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
        # Extract the basename to use in the uploads folder
        my $storage_dir = 'uploads';
        mkdir $storage_dir unless -d $storage_dir;  # Ensure uploads directory exists

        my $file_name = basename($filepath);
        my $target_path = "$storage_dir/$file_name";

        print $client_socket "READY_TO_RECEIVE\n";  # Notify the client

        open my $file, '>:raw', $target_path or do {
            print $client_socket "ERROR: Unable to open file $target_path for writing.\n";
            next;  # Skip further processing if file cannot be opened
        };

        # Receive and write file data
        while (my $buffer = <$client_socket>) {
            last if $buffer =~ /EOF/;  # Stop on end-of-file marker
            print $file $buffer;
        }
        close $file;

        # Log ownership of the uploaded file
        $file_owners{$file_name} = $username;
        save_file_ownership();

        print $client_socket "UPLOAD SUCCESS\n";
        broadcast_event("$username uploaded '$file_name'");
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

    if (-e $file_path && $file_owners{$filename} eq $username) {
        unlink $file_path or do {
            print $client_socket "ERROR: Could not delete file '$filename'.\n";
            return;
        };

        delete $file_owners{$filename};
        save_file_ownership();

        broadcast_event("$username deleted '$filename'");
        print $client_socket "DELETE SUCCESS: File '$filename' has been deleted.\n";
    } else {
        print $client_socket "ERROR: File not found or permission denied.\n";
    }
}

# Load file ownership data
sub load_file_ownership {
    if (-e $ownership_file) {
        open my $fh, '<', $ownership_file or die "Could not open ownership file: $!";
        while (<$fh>) {
            chomp;
            my ($filename, $owner) = split /:/;
            $file_owners{$filename} = $owner;
        }
        close $fh;
    }
}

sub save_file_ownership {
    open my $fh, '>', $ownership_file or die "Could not open ownership file\n";
    foreach my $filename (keys %file_owners) {
        print $fh "$filename:$file_owners{$filename}\n";
    }
    close $fh;
}

sub broadcast_event {
    my ($message) = @_;
    foreach my $user (keys %monitoring_clients) {
        foreach my $socket (@{$monitoring_clients{$user}}) {
            print $socket "NOTIFICATION: $message\n";
        }
    }
}