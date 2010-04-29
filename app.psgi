use lib 'lib';
use PeeStream;
use Plack::Builder;

builder {
  enable "Static", path => qr{^/static/};
  mount "/" => PeeStream->new->to_psgi;
}
