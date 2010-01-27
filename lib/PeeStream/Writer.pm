package PeeStream::Writer;

use 5.010;
use strict;
use warnings;
use Any::Moose;
use Try::Tiny;

has req => (
  is  => 'ro',
  isa => 'Plack::Request',
  required => 1,
); 

has writer => (
  is  => 'rw',
);

has connected => (
  is  => 'rw',
  isa => 'Bool',
  default => 1,
);

has started => (
  is  => 'rw',
  isa => 'Bool',
  default => 0,
);

has seperator => (
  is  => 'ro',
  default => 'xpeestreamx',
);

sub respond {
  my $self = shift;
  return sub {
    my $respond = shift;
    my $writer = $respond->([200, ['Content-Type', 'application/json']]);
    $self->writer($writer);
  }
}

sub send {
  my ($self, $json) = @_;
  try {
    if (! $self->started) {
      $json = "--".$self->seperator."\n$json";
      $self->started(1);
    }
    $self->writer->write($json);
  } catch {
    warn "Got error: $_\n";
    $self->connected(0);
  }
}

1;
