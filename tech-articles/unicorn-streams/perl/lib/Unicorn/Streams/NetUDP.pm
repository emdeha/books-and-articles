package Unicorn::Streams::NetUDP;

use strict;
use warnings;
use v5.006;


use IO::Socket::INET;

use Exporter qw/import/;
our @EXPORT_OK = qw/simple_connection/;


# TODO: How do we clean-up the mess?
sub simple_connection {
  my %args = @_;
  my $port = $args{port};

  my $socket = new IO::Socket::INET(
    LocalPort => $port,
    Proto => 'udp'
  ) or die "Cannot create UDP socket for stream; $!";

  return sub {
    my $data;
    $socket->read($data, 1);

    return $data;
  }
}


1;
