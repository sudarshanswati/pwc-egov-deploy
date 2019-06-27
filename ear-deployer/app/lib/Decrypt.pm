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

sub get
{
	my $password = shift;
	#my $KEY = $ENV{'EGOV_SECRET_PASSCODE'};
	my $KEY = $ENV{'EAR_PASSCODE'};
	my $cipher = Crypt::CBC->new(
    -key        => $KEY,
    -cipher     => 'Blowfish',
    -padding  	=> 'space',
    -header 	=> 'salt',
    -salt		=> 1
    );
    my $decrypt = $cipher->decrypt(decode_base64($password));
    return $decrypt;
}
1;
