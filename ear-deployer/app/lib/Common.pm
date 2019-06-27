=head
# ##################################
# 
# Module : Setup.pm
#
# SYNOPSIS
# Common script (Jenkins Auth, Download Artifact).
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
package Common;

use strict;
use FindBin;

sub get_log_filename
{
	my $LOG_DATE = `date +%d%h%y_%H%M`;
	chomp($LOG_DATE);
	return 'deployment_'.$LOG_DATE.'.log';	
}

sub init {
	my ($logger, $DEPLOY_HOME, $configFile) = @_;
	my $DEPLOY_RUNTIME = $ENV{'HOME'}."/.deploy-runtime";
	my $DEPLOY_RUNTIME_STATUS = ( !-d $DEPLOY_RUNTIME ) ? (deploy::make_path( $DEPLOY_RUNTIME , { mode => 0755}) && "Created DEPLOY_RUNTIME folder") : "Already exists DEPLOY_RUNTIME folder.." ;
	$logger->info("$DEPLOY_RUNTIME_STATUS");
	chdir ($DEPLOY_RUNTIME);
	#####################################################################
	$logger->info("Clean up deplpoy-runtime temp folder ...!");
	deploy::remove_tree( $DEPLOY_RUNTIME."/tmp", { error => \my $err2 } );
	# Load ENV specific file
	my $config = deploy::LoadFile("$configFile");#  or ($logger->error("Cannot open configuration file $envConfigFile : No such file or directory.") and exit 1);
	return ($config,$DEPLOY_RUNTIME);
}

sub jenkinsAuthToken
{
	my ($logger,$par_template_dir,$environment,$buildnumber,$config) = @_;
	my $uagent = LWP::UserAgent->new;
	$logger->info("CI Authentication requested ...");
	my $req = HTTP::Request->new( GET => $config->{'config'}->{'jenkins'}->{'url'}."/".$buildnumber."/api/json?pretty=true&depth=1" );
	$req->header('content-type' => 'application/json');
	$req->authorization_basic(Decrypt::get($config->{'config'}->{'jenkins'}->{'username'}), Decrypt::get($config->{'config'}->{'jenkins'}->{'authtoken'}));
	$uagent->ssl_opts( verify_hostname => 0 );
	my $response = $uagent->request($req);
	($response->is_success) ? $logger->info('CI token authenticated successfully.') : ( $logger->error( "Jenkins error code - ". $response->status_line."\n")
	&& Email::notify_deployment_failure($logger,$config->{'config'}->{'tenant.name'},$par_template_dir,$config,$environment,"Jenkins ERROR code : ". $response->status_line,$buildnumber) && exit 1);
	return $response->decoded_content;
}

sub getBuildNumbers 
{
	my ($logger,$JOB_CONTENT) = @_;
	my $platform_buildnumber;
	foreach (@{$JOB_CONTENT->{actions}})
	{
	       $platform_buildnumber = $_->{number} foreach @{($_->{triggeredBuilds})};
	}
	if (defined $JOB_CONTENT->{number} && defined $platform_buildnumber)
	{
		$logger->info("Tenant build number : $JOB_CONTENT->{number}  && Platform build number : $platform_buildnumber");
	}
	else
	{
		$logger->info("Tenant build number : $JOB_CONTENT->{number}");
	}
}

sub downloadJenkinsArtifact
{
	my ( $logger,$par_template_dir,$config,$environment,$JOB_CONTENT,$DEPLOY_RUNTIME,$buildnumber ) = @_;
	my ( $api_git_url, $SCM_DETAILS,$api_artiRelativePath,$api_artifilename );
	my $jenkinsUserName = Decrypt::get($config->{'config'}->{'jenkins'}->{'username'});
	my $jekinsAuth = Decrypt::get($config->{'config'}->{'jenkins'}->{'authtoken'});
	my $JENKINS_JOB_URL = $config->{'config'}->{'jenkins'}->{'url'};
	my %API_SCM_HASH;
	foreach $SCM_DETAILS (@{$JOB_CONTENT->{actions}})
	{
		$API_SCM_HASH{'branchname'} = $_->{name} foreach @{$SCM_DETAILS->{lastBuiltRevision}->{branch}};
	 	$API_SCM_HASH{'SHA1'} = $_->{SHA1} foreach @{$SCM_DETAILS->{lastBuiltRevision}->{branch}};
		$api_git_url = $_ foreach @{$SCM_DETAILS->{remoteUrls}};
	}
	$api_artiRelativePath =  $_->{relativePath} foreach @{($JOB_CONTENT->{artifacts})};
	$api_artifilename =  $_->{fileName} foreach @{$JOB_CONTENT->{artifacts}};
	my $api_arti_version = `echo $api_artifilename | awk -F '-' '{print \$(NF-1)"-"\$(NF)}' | rev | cut -d. -f2- | rev`;
	my $snapshot_details = $API_SCM_HASH{'SHA1'}."::".$API_SCM_HASH{'branchname'}."::".$api_artifilename."::".$api_arti_version."::".$api_git_url;

	my $hostAddress      = Net::Address::IP::Local->public;
	$hostAddress =~ s/\n//g;
	chomp $hostAddress;
	if ( $hostAddress )
	{			
			$logger->info("Downloading the EAR Artifact from CI to Deployer Agent ==> ".$hostAddress);
			if ( not -w $DEPLOY_RUNTIME ) 
			{
		        $logger->fatal("Directory '".$DEPLOY_RUNTIME."' is not writable...Permission denied.");
		        exit 1;
		    }
			#my $returnCode = system("curl -X POST https//".$jenkinsUserName.":".$jekinsAuth."@".$JENKINS_JOB_URL."/".$buildnumber."/artifact/".$api_artiRelativePath." -o ".$DEPLOY_RUNTIME."/".$api_artifilename);
			my $returnCode = system("wget -nv --auth-no-challenge --http-user=".$jenkinsUserName." --http-password=".$jekinsAuth." --waitretry=60 ".$JENKINS_JOB_URL."/".$buildnumber."/artifact/".$api_artiRelativePath." -O ".$DEPLOY_RUNTIME."/".$api_artifilename);
			if ( $returnCode == 0 )
			{
				$logger->info($api_artifilename." downloaded to RUNTIME folder ==> ".$DEPLOY_RUNTIME);
			}
			else 
			{
				$logger->error("Unable to download the ".$api_artifilename." file.");
				exit 1;	
			}
		return ($api_artifilename,$snapshot_details);
	}
}

sub usage
{
	my ( $logger, $environment, $buildnumber, $envConfigFile ) = @_;
	if ( ! defined $environment || ! defined $buildnumber || ! defined $envConfigFile )
	{
		$logger->error("Invalid Options...!\n\n Usage: $0 -e <environment> -b <build-number> -c <config.yml>\n Options:
		-e, --environment	Specify environment <dev/qa/uat/prod>.
		-b, --buildnumber	Specify the build number og environment specific Job.
		-c, --config 		Specify the configuration file name..\n
		\n");
		exit 1;
	}
	die "\nERROR : $envConfigFile does not exists...!!!\n\n" unless (-e $envConfigFile);
}

1;
