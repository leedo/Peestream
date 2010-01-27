package PeeStream;

use strict;
use warnings;
use 5.010;

use PeeStream::Writer;
use Plack::Request;
use HTML::Entities;
use Text::MicroTemplate::File;
use AnyEvent;
use Any::Moose;
use Path::Class;
use JSON;

has mtf => (
  is  => 'ro',
  isa => 'Text::MicroTemplate::File',
  default => sub {
    Text::MicroTemplate::File->new(
      include_path => ['templates'],
      use_cache => 1
    )
  }
);

has static => (
  is  => 'ro',
  isa => 'Path::Class::Dir',
  default => sub {dir('static')},
);

has streams => (
  is  => 'rw',
  isa => 'ArrayRef[PeeStream::Writer]',
  default => sub {[]},
);

has queue => (
  is  => 'rw',
  isa => 'ArrayRef[Str]',
);

has messages => (
  is  => 'rw',
  isa => 'ArrayRef[Str]',
  default => sub {[]},
);

has last_broadcast => (
  is  => 'rw',
  isa => 'Int',
  default => sub {time},
);

sub to_psgi {
  my $self = shift;
  return sub { $self->call(@_) };
}

sub call {
  my ($self, $env) = @_;
  my $req = Plack::Request->new($env);
  $self->purge_streams;
  given ($req->path) {
    when (/^\/stream\/?$/) {
      my $stream = PeeStream::Writer->new(req => $req);
      push @{$self->streams}, $stream;
      return $stream->respond;
    }
    when (/^\/post\/?$/) {
      if (my $msg = $req->param('msg')) {
        my $author = $req->param('author');
        my $html = $self->mtf->render_file("message.html", $author, $msg);
        $html .= " " x (1024 - length($html));
        push @{$self->queue}, "$html";
        $self->broadcast;
      }
      return [200, [], ['ok']];
    }
    when (/^\/static\/(.+)/) {
      my $file = $self->static->file($1);
      if ($self->static->contains($file)) {
        my $fh = $self->static->file($1)->openr;
        my $mime;
        given ($file->basename) {
          when (/\.js$/)  {$mime = "text/javascript"}
          when (/\.jpg$/) {$mime = "image/jpeg"}
          when (/\.gif$/) {$mime = "image/gif"}
          when (/\.png$/) {$mime = "image/png"}
        }
        return [200, ['Content-Type',$mime], $fh];
      }
    }
    default {
      my $html = $self->mtf->render_file("index.html", $self);
      return [200, ['Content-Type','text/html'],[$html]];
    }
  }
}

sub purge_streams {
  $_[0]->streams([grep {$_->connected} @{$_[0]->streams}]);
}

sub broadcast {
  my $self = shift;
  my $json = to_json($self->messages);
  $_->send($json) for @{$self->streams};
  push @{$self->messages}, @{$self->queue};
  $self->queue([]);
}

1;
