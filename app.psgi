use lib 'lib';
use PeeStream;

my $app = PeeStream->new->to_psgi;

return $app;
