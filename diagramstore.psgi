#! perl
use strict;
use warnings;
use JSON;
use Redis;
use Encode qw(encode_utf8 decode_utf8);
use Digest::SHA qw(sha256_base64);

use constant MAX_DATA => 32 * 1024 * 1024;
my $json = JSON->new->canonical->utf8;

my $app = sub {
    my $env = shift;
    my $namespace = 'diagramstore::';
    my $r = Redis->new;
    if ($env->{REQUEST_METHOD} eq 'POST') {
	my $data;
	$env->{'psgi.input'}->read($data, MAX_DATA);
	$data = $json->decode($data);
	return [ 403, [], [] ]
	  unless $data->{'@context'} =~ m{^https://graph-explorer\.org/context/v\d+\.json$};
	$data = $json->encode($data);
	my $digest = sha256_base64($data);
	$digest =~ y|+/|-_|;
	$r->set("$namespace$digest", $data);
	return [ 200,
		 [ 'Content-type' => 'application/json',
		   'Access-Control-Allow-Origin' => '*' ],
		 [ $json->encode(+{
		     data => {
			 frag => $digest
		     },
		 }) ]
		];
    }
    my $digest = $env->{PATH_INFO} =~ s{^/}{}r;
    my $data = $r->get("$namespace$digest");
    return [ 404, [], [] ] unless $data;
    return [ 200,
	     [ 'Content-type' => 'application/ld+json',
	       'Access-Control-Allow-Origin' => '*' ],
	     [ $data ]
	   ];
};

$app;
