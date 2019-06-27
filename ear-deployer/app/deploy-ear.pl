#!/usr/bin/perl 
=head
# ##################################
# Module : deploy
#
=cut

# Add template folder to PAR file
# PAR Packager : pp -a template -M Crypt::Blowfish -M JSON -M Decrypt.pm -M DateTime -M Email.pm -M Nexus.pm -M Wildfly.pm -M Common.pm --clean -o deploy-ap-ear deploy-ap-ear.pl

# Package name
package deploy;

use strict;
use FindBin;
use LWP;
use JSON;
use Getopt::Long;
use Cwd;
use utf8;
use Encode;
use Cwd 'abs_path';
use File::Tee qw(tee);
use File::Basename;
use File::Path qw(make_path remove_tree);
use Log::Log4perl qw(:easy);
use HTML::Template;
use Data::Dumper qw(Dumper);
use Config::Properties;
use Net::SMTP::SSL;
use Net::Address::IP::Local;
use Crypt::CBC;
use MIME::Base64;
use Net::SSH::Perl;
use YAML::XS qw(LoadFile);

use lib "$FindBin::Bin/lib";
use Common;
use Nexus;
use Wildfly;
use Email;
use Decrypt;
use Redis;

use constant TRUE => 1;
use constant FALSE => 0;

## PAR TEMP path to get the Template path
my ($environment, $buildnumber, $configFile, $error_flag, $par_template_dir, $nexus_ds_filename);

my $DEBUG = 0;
if ( $DEBUG == TRUE )
{
	$par_template_dir = $FindBin::Bin."/template";
}
else
{
	$par_template_dir = "$ENV{PAR_TEMP}/inc/template";
}
#############################################
Log::Log4perl->easy_init($ERROR);
my $conf = q(	log4perl.logger      = DEBUG, Screen, File
    			log4perl.appender.Screen        = Log::Log4perl::Appender::Screen
    			log4perl.appender.Screen.stderr = 1
    			log4perl.appender.Screen.mode   = append
    			log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
    			log4perl.appender.Screen.layout.ConversionPattern = %d %p - %m%n
    			log4perl.appender.File=Log::Log4perl::Appender::File
    			log4perl.appender.File.stderr = 1
    			log4perl.appender.File.filename=sub { Common::get_log_filename(); }
    			log4perl.appender.File.mode=append
    			log4perl.appender.File.layout=Log::Log4perl::Layout::PatternLayout
    			log4perl.appender.File.layout.ConversionPattern=%d %p - %m%n
    			);
Log::Log4perl::init(\$conf);
my $logger = get_logger();

Getopt::Long::GetOptions(
	   'environment|e=s' => \$environment,
	   'buildnumber|b=i' => \$buildnumber,
	   'config|c=s'  => \$configFile
	) or die "Usage: $0 -e <environment> -b <build-number> -c <config.yml>\n";

chomp $environment && chomp $buildnumber && chomp $configFile;

#####################################################################
	Common::usage( $logger, $environment, $buildnumber, $configFile ); # Usage
	my ($config,$DEPLOY_RUNTIME) = Common::init($logger, $FindBin::Bin, $configFile); #Init and Validate Conf
	$logger->info("Initiating the Deployment on ".$environment." environment");
	$logger->info("Notify about the deployment to subscribers."); #Send Deploy Notification
	Email::notify_deployment_alert($logger,$par_template_dir,$environment,$config,$buildnumber); 
	my $JOB_CONTENT = decode_json(Common::jenkinsAuthToken($logger,$par_template_dir,$environment,$buildnumber,$config)); ## Jenkins job details
	Common::getBuildNumbers($logger,$JOB_CONTENT);
	my ($EAR_ARTIFACT_NAME,$snapshot_details) = Common::downloadJenkinsArtifact($logger,$par_template_dir,$config,$environment,$JOB_CONTENT,$DEPLOY_RUNTIME,$buildnumber); #Download Artifact, And EAR PACK
	Wildfly::earPackage($logger,$config,$DEPLOY_RUNTIME,$EAR_ARTIFACT_NAME,$nexus_ds_filename,$environment);
	Wildfly::flushrestart($logger,$config,$environment ); #Wildfly restart, cleanup temp dir
	Wildfly::validate_mgmt_status($logger,$config,$par_template_dir,$environment,$buildnumber); # Validate Wildfly Management is running
	if ( $config->{$environment.'-config'}->{'redis'}->{'flush.enabled'} eq "TRUE" ) 
	{
		Redis::flushall($logger,$config,$environment );
	}
# DEPLOY Downloaded Artifact
	Wildfly::deployEar($logger,$DEPLOY_RUNTIME,$par_template_dir,$EAR_ARTIFACT_NAME,$config,$snapshot_details,$environment,$buildnumber);
#rmdir ($DEPLOY_RUNTIME);
exit 0;
