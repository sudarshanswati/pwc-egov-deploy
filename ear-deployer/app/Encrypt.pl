#!/usr/bin/perl

# Package name
package Encrypt;

use warnings;
use strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use Crypt::CBC;
use MIME::Base64;
use Decrypt;

############################################################
sub main {
    my ($password) = @_;
    my $KEY = $ENV{'EAR_PASSCODE'};
    my $cipher = Crypt::CBC->new(
    -key        => $KEY,
    -cipher     => 'Blowfish',
    -padding  	=> 'space',
    -header => 'salt',
    -salt		=> 1
    );
    return encode_base64($cipher->encrypt($password));
}
my $pass = main($ARGV[0]);
print "Encrypted Value\t: $pass";
print "Actual String\t: ".Decrypt::get($pass)."\n";
###################################################################
