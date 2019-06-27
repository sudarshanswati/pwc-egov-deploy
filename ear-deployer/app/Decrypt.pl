=head
# ##################################
# 
# Module : Decrypt.pm
#
# SYNOPSIS
# Decrypt Password
#
# Copyright 2015 eGovernments Foundation
#
#  Log
#  By          	Date        	Change
#  Vasanth KG  	29/11/2015	    Initial Version
#
# #######################################
=cut

# Package name
package Decrypt;

use warnings;
use strict;
use FindBin;
use Crypt::CBC;
use MIME::Base64;

	my $password = $ARGV[0];
	my $KEY = "$ENV{'EAR_PASSCODE'}";
	my $cipher = Crypt::CBC->new(
    -key        => $KEY,
    -cipher     => 'Blowfish',
    -padding  	=> 'space',
    -header 	=> 'salt',
    -salt		=> 1
    );
    my $decrypt = $cipher->decrypt(decode_base64($password));
    print "Encrypted Value \t: ".$password."\n";
    print "Decrypted Value \t: ".$decrypt."\n";

