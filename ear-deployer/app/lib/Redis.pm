=head
# ##################################
# 
# Module : Redis.pm
# #######################################
=cut

# Package name
package Redis;

use strict;
use FindBin;
use Data::Dumper;

sub flushall
{
	my($logger,$config,$environment ) = @_;
	my $result = system("redis-cli -h $config->{'config'}->{'redis'}->{'hostaddr'} flushall  > /dev/null 2>&1");
    $logger->info("[ SUCCESS ] REDIS SERVER FLUSH - $config->{'config'}->{'redis'}->{'hostaddr'}") if ( $result == 0 );
}
1;