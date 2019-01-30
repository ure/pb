#!/usr/bin/perl

use IO::Socket::INET;
use WWW::PushBullet;
use File::Slurp;
use Sys::Hostname;
use Env qw(HOME);

# auto-flush on socket
$| = 1;

# hostname
my $host = hostname;

# apikey
if ( !-e $HOME . "/.pb.key" ) {
    print "Store PushBullet API key in ~/.pb.key\n";
    exit;
}
my $apikey = read_file( $HOME . '/.pb.key' );
chomp($apikey);

my $pb = WWW::PushBullet->new( { apikey => $apikey } );

# only one file
if ( $ARGV[1] ) { print "One file or STDIN\n"; exit; }

my $directurl;
my $data;

# stdin or file ?
if ( !$ARGV[0] ) {

    # read data from stdin
    while (<STDIN>) {
        $data .= $_;
    }
    $directurl = $data if $data =~ /^http/;
}
else {
    # does file exists ?
    if ( !-e $ARGV[0] ) { print "No such file $ARGV[0]\n"; exit; }
    $data = read_file( $ARGV[0] );
}

if ( defined $directurl ) {
    $directurl =~ s/\s+$//;

    # send to pushbullet
    $pb->push_link(
        {
            title => $host,
            url   => $directurl
        }
    );
    print "send url: " . $directurl . "\n";

}
else {

    # create a connecting socket
    my $socket = new IO::Socket::INET(
        PeerAddr => 'pb.weepee.io',
        PeerPort => '9999',
        Proto    => 'tcp',
    );
    die "cannot connect to pb.weepee.io$!\n" unless $socket;

    # data to send to a server
    my $size = $socket->send($data);

    # notify server that request has been sent
    shutdown( $socket, 1 );

    # receive a response of up to 1024 characters from server
    my $response = "";
    $socket->recv( $response, 1024 );

    $socket->close();

    $response =~ s/\s+$//;

    # send to pushbullet
    $pb->push_link(
        {
            title => 'pb.weepee.io',
            url   => $response
        }
    );

    print $response;
}
