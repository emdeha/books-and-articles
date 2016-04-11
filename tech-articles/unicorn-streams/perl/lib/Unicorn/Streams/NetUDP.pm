package Unicorn::Streams::NetUDP;

use strict;
use warnings;
use v5.006;


use IO::Socket::INET;

use Exporter qw/import/;
our @EXPORT_OK = qw/simple_connection simple_immutable_connection/;
our %EXPORT_TAGS = (all => [@EXPORT_OK]);


# TODO: How do we clean-up the mess?
sub simple_immutable_connection {
  my %args = @_;
  my $port = $args{port};

  my $socket = new IO::Socket::INET(
    LocalPort => $port,
    Proto => 'udp'
  ) or die "Cannot create UDP socket for stream; $!";

  my @cache;

  return sub {
    my $head = shift;

    my $idx;
    if (!defined $head) {
      $idx = 0;
    } else {
      ($idx, undef) = @$head;
    }

    my $data;
    if ($idx > $#cache) {
      $socket->read($data, 1);
      push @cache, $data;
    } else {
      $data = $cache[$idx];
    }

    return [$idx+1, $data];
  }
}

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
