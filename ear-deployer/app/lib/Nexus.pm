=head
# ##################################
# 
# Module : Nexus.pm
#
# SYNOPSIS
# Download artifact from Nexus
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
package Nexus;

use strict;
use FindBin;

sub downloadDSArtifact
{
	my ( $logger,$DEPLOY_RUNTIME,$config,$environment ) = @_;

		my $NEXUS_HOME_URL 		= $config->{'nexus'}->{'url'};
		my $NEXUS_PRIVATE_REPO 	= $config->{'nexus'}->{'private.repository'};
		my $NEXUS_GROUP_ID		= $config->{'nexus'}->{'group.id'};
		my $NEXUS_ARTIFACT_ID	= $config->{'nexus'}->{'artifact.id'};
		my $NEXUS_PACKAGE_TYPE	= $config->{'nexus'}->{'package.type'};
		my $NEXUS_VERSION		= $config->{'nexus'}->{'version.id'};

		my $NEXUS_UAERNAME		= $config->{'nexus'}->{'username'};
		my $NEXUS_PASSWORD		= $config->{'nexus'}->{'password'};

		my $contentContext = "content/repositories";
		my $filename = $NEXUS_ARTIFACT_ID."-".$NEXUS_VERSION.".".$NEXUS_PACKAGE_TYPE;
		if ( not -w $DEPLOY_RUNTIME ) 
		{
	        $logger->fatal($DEPLOY_RUNTIME." Directory is not writable...Permission denied.");
	        exit 1;
	    }
		$NEXUS_GROUP_ID =~ s/\./\//g;
		#my $metadata = "maven-metadata.xml";
		my $DIGI_SIGN_URL= $NEXUS_HOME_URL."/".$contentContext."/".$NEXUS_PRIVATE_REPO."/".$NEXUS_GROUP_ID."/".$NEXUS_ARTIFACT_ID."/".$NEXUS_VERSION."/".$filename;
		#$logger->info($DIGI_SIGN_URL);
		$logger->info("Downloading Digital Signature Artifact ".$filename." from Nexus");
		my $uagent = LWP::UserAgent->new;
		my $req = HTTP::Request->new( GET => $DIGI_SIGN_URL );
		$uagent->ssl_opts( verify_hostname => 0 );

		my $response = $uagent->request($req,$DEPLOY_RUNTIME."/".$filename);
		if ($response->is_success)
		{
			$logger->info($filename." downloaded to ".$DEPLOY_RUNTIME);
		}
		else 
		{
			$logger->error("Unable to download the ".$filename." file : ".$response->message);	
			exit 1;
		}
		return ($filename);
}
1;