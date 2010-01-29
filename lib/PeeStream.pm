package PeeStream;

use strict;
use warnings;
use 5.010;

use PeeStream::Writer;
use PeeStream::Message;
use Plack::Request;
use Text::MicroTemplate qw/encoded_string/;
use Text::MicroTemplate::File;
use AnyEvent;
use Any::Moose;
use Path::Class;
use Try::Tiny;
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
  default => sub {[]},
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
      my $msg = PeeStream::Message->new(
        author => $req->param("author") || "Anonymous",
        body   => $req->param('msg'),
        images => $req->uploads->{image},
      );
      if ($msg->body or @{$msg->images}) {
        my $html = $self->mtf->render_file("message.html", $msg);
        push @{$self->queue}, "$html";
        $self->broadcast;
        return [200, [], ['ok']];
      }
      else {
        return [500, [], ["Unable to add message: $_"]];
      }
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
        return [200, ['Content-Type', $mime], $fh];
      }
      return [400, ['Content-Type', 'text/plain'], ['not found']];
    }
    when ("/") {
      my $html = $self->mtf->render_file("index.html", $self);
      return [200, ['Content-Type','text/html'],[$html]];
    }
    default {
      return [404, ['Content-Type', 'text/html'], ['not found']];
    }
  }
}

sub purge_streams {
  $_[0]->streams([grep {$_->connected} @{$_[0]->streams}]);
}

sub broadcast {
  my $self = shift;
  my $json = to_json($self->queue);
  $json .= " " x (1024 - length $json) if length $json < 1024;
  $json .= "\n--xpeestreamx\n";
  $_->send($json) for @{$self->streams};
  push @{$self->messages}, map {encoded_string($_)} @{$self->queue};
  $self->queue([]);
}

1;
