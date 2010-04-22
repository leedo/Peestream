package PeeStream::Upload;

use Any::Moose;
use File::Copy;

has upload => (
  is => 'ro',
  isa => 'Plack::Request::Upload',
  required => 1,
);

has path => (
  is => 'rw'
);

has filename => (
  is => 'rw',
);

has is_image => (
  is => "rw",
  isa => "Bool",
  default => 0
);

sub BUILD {
  my $self = shift;
  unless (-d "static/upload") {
    mkdir "static/upload" or die $!;
  }
  if (($self->upload->content_type =~ /^image\/.+/)) {
    $self->is_image(1);
  }
  my $path = "static/upload/".$self->upload->filename;
  copy($self->upload->path, $path);
  $self->path($path);
  $self->filename($self->upload->filename);
}

1;
