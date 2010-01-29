package PeeStream::Message;

use 5.010;
use strict;
use warnings;

use Any::Moose;

has body => (
  is => 'ro',
  isa => 'Str',
);

has images => (
  is  => 'rw',
  isa => 'ArrayRef[Path::Class::File]',
  default => sub {[]},
);

has author => (
  is => 'ro',
  isa => 'Str',
  required => 1,
  default => "Anonymous",
);

has datetime => (
  is => 'ro',
  isa => 'Str',
  default => sub {
    my ($min, $hour, $day, $mon, $year) = (localtime(time))[1,2,3,4,5];
    return sprintf "%02d:%02d %02d/%02d/%02d", $hour, $min, $mon+1, $day, $year%100;
  },
);

1;