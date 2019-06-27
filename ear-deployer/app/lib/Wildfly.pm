=head
# ##################################
# 
# Module : Wildfly.pm
#
# SYNOPSIS
# This script to deploy the EAR to Wildfly.
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
package Wildfly;

use strict;
use FindBin;
use Data::Dumper;

sub wildflyStop
{
        my ($logger, $WILDFLY_HOME, $result) = @_;
        my $WILDFLY_PID=`ps -ef | grep -v grep | grep -i java | grep $WILDFLY_HOME | awk '{print \$2}'`;
        chomp $WILDFLY_PID;
        if ( $WILDFLY_PID ne "" )
        {
                $result = system("kill -9 $WILDFLY_PID");
        }
        $logger->info("Wildfly Stopped...") if ( $result == 0 );
        sleep 2;
}

sub wildflyStart
{
        my ($logger, $WILDFLY_HOME) = @_;
        $logger->info("Starting Wildfly...");
        system("cd ".${WILDFLY_HOME}."/bin && nohup ./standalone.sh -b 0.0.0.0 >> /dev/null 2>&1 &");
        sleep 20;
}

sub removeWildflyTmp
{
        my ($logger, $WILDFLY_HOME) = @_;
        system("rm -rf ${WILDFLY_HOME}/standalone/tmp");
	system("rm -rf ${WILDFLY_HOME}/standalone/data");
        system("rm -rf ${WILDFLY_HOME}/standalone/deployment/egov.ear*");
        $logger->warn("Clean up wildfly tmp directory.");
        sleep 2;
}


sub removeDeployTag
{
	my ($logger, $WILDFLY_HOME) = @_;
	system('sed -ie "/<deployments>.*/,/<\/deployments>/d" '.${WILDFLY_HOME}.'/standalone/configuration/standalone.xml');
	#system("cp -rp ${WILDFLY_HOME}/standalone/configuration/standalone-eGov-template.xml ${WILDFLY_HOME}/standalone/configuration/standalone.xml");
	#$logger->warn("Replaced the standalone.xml with eGov template to remove the Deployment TAG.");
	$logger->warn("Removed the previous Deployment TAG from standalone.xml");
	sleep 2;
}

sub deployEar
{
	my ( $logger,$DEPLOY_RUNTIME,$par_template_dir,$EAR_ARTIFACT_NAME,$config,$snapshot_details,$environment,$buildnumber ) = @_;
	my $WILDFLY_HOME = "$config->{'config'}->{'wildfly'}->{'home.path'}";

	foreach my $wildfly_host (@{$config->{'config'}->{'wildfly'}->{'host.addr'}})
	{
		$logger->info("Deplying to node ==> ".$wildfly_host);
		my ( $status ) = publish($logger,$par_template_dir,$DEPLOY_RUNTIME,$EAR_ARTIFACT_NAME,$config,$snapshot_details,$environment,$buildnumber,$wildfly_host);
		if ( $status eq "success" )
		{
			$logger->info("Deployment was successful on Node ( ".$wildfly_host." )");
		}
		
	}
	#Notify successful deployment
	$logger->info("Notify the deployment successful status to team.");
	Email::notify_deployment_success( $logger,$config->{'config'}->{'tenant.name'},$par_template_dir,$config,$snapshot_details,$environment,$buildnumber); 
}

sub publish
{
	my ( $logger,$par_template_dir,$DEPLOY_RUNTIME,$EAR_ARTIFACT_NAME,$config,$snapshot_details,$environment,$buildnumber,$hostname) = @_;
	my $WILDFLY_USERNAME = Decrypt::get($config->{'config'}->{'wildfly'}->{'mgmt'}->{'username'});
	my $WILDFLY_PASSWORD = Decrypt::get($config->{'config'}->{'wildfly'}->{'mgmt'}->{'password'});
	my $WILDFLY_MGMT_PORT = "$config->{'config'}->{'wildfly'}->{'mgmt'}->{'port'}";
	my ($API_SCM_HASH,$API_SCM_BRANCH,$api_artifilename,$api_arti_version,$api_git_url) = split('::',$snapshot_details);
	$logger->info(" ========== EAR Publish ===========");
	sleep 1;
	# Undeploy existing earAPI_SCM_BRANCH
		$logger->info("Undeploying old EAR on ".$hostname);
		my $undeploy_status = `curl -s -S -H "content-Type: application/json" -d '{"operation":"undeploy", "address":[{"deployment":"$api_artifilename"}]}' --digest http://$WILDFLY_USERNAME:$WILDFLY_PASSWORD\@${hostname}:$WILDFLY_MGMT_PORT/management`;		
		my $undeploy_json = deploy::decode_json($undeploy_status);
		( $undeploy_json->{outcome} eq "success" ) ? $logger->info("Undeployed old '".$api_artifilename."' successfully") :
		$logger->warn("Failed or already undeploy the EAR '".$api_artifilename."'");
		#print Dumper $undeploy_json;
	# Remove old ear
		$logger->info("Removing old EAR on ".$hostname);
		my $remove_status = `curl -s -S -H "content-Type: application/json" -d '{"operation":"remove", "address":[{"deployment":"$api_artifilename"}]}' --digest http://$WILDFLY_USERNAME:$WILDFLY_PASSWORD\@${hostname}:$WILDFLY_MGMT_PORT/management`;
		my $remove_json = deploy::decode_json($remove_status);
		( $remove_json->{outcome} eq "success" ) ? $logger->info("Removed the old '".$api_artifilename."' successfully") :
		($logger->warn("Failed to remove the EAR '".$api_artifilename."'") && 
		$logger->warn($remove_json->{'failure-description'}));
		sleep 1;
	# Upload new EAR
		$logger->info("Uploading new EAR on ".$hostname);
		my $upload_status = `curl -s -F "file=\@${DEPLOY_RUNTIME}/${api_artifilename}" --digest http://$WILDFLY_USERNAME:$WILDFLY_PASSWORD\@${hostname}:$WILDFLY_MGMT_PORT/management/add-content --max-time $config->{'config'}->{'timeout'}`;
	    my $upload_json = deploy::decode_json($upload_status);
	    ( $upload_json->{outcome} eq "success" ) ? $logger->info("New EAR '".$api_artifilename."' has been uploaded successfully") :
		($logger->error("Failed to upload the new EAR '".$api_artifilename."'")
		&& $logger->error($remove_json->{'failure-description'}) && exit 1);
		sleep 1;
	# Deploy new EAR
		$logger->info("Deploying new EAR '".$api_artifilename." on ".$hostname);
		my $deploy_status = `curl -s -S -H "Content-Type: application/json" -d '{"content":[{"hash": {"BYTES_VALUE" : "$upload_json->{result}->{BYTES_VALUE}"}}], "address": [{"deployment":"${api_artifilename}"}], "operation":"add", "enabled":"true"}' --digest http://$WILDFLY_USERNAME:$WILDFLY_PASSWORD\@${hostname}:$WILDFLY_MGMT_PORT/management  --max-time $config->{'config'}->{'timeout'}`;
		my $deploy_json = deploy::decode_json($deploy_status);
		#print Dumper ($deploy_json);
		if ( $deploy_json->{outcome} eq "success")
		{
			
			return ($deploy_json->{outcome},$snapshot_details,$environment,$buildnumber); 
		}
		else
		{
			$logger->error("Deployment failed on Node ( ".$hostname." )");
			open(my $fh, '>', 'deploy_failure.txt');
				print $fh Dumper $deploy_json->{'failure-description'};
			close $fh;
			print Dumper $deploy_json->{'failure-description'};
			$logger->info("Notify the deployment failure to team.");
			Email::notify_deployment_failure($logger,$config->{'config'}->{'tenant.name'},$par_template_dir,$config,$environment,"Error log attached with this mail.",$buildnumber,$hostname,'deploy_failure.txt');
			exit 1;
		}
}

sub earPackage
{
	my ( $logger,$config,$DEPLOY_RUNTIME,$api_artifilename,$nexus_ds_filename,$environment ) = @_;
	my $DEPLOY_RUNTIME_TEMP = $DEPLOY_RUNTIME."/tmp";
	
	if ( $config->{'config'}->{'digisign'}->{'enabled'} eq "TRUE" || $config->{'config'}->{'cdn'}->{'enabled'} eq "TRUE" )
	{
		my $tmp_status = ( !-d $DEPLOY_RUNTIME_TEMP ) ? (make_path( $DEPLOY_RUNTIME_TEMP, { mode => 0755}) && "Created RUNTIME temp folder") : "Already exists RUNTIME temp folder.." ;
		$logger->info($tmp_status);
		$logger->info("Packing the Digital Signature to EAR.");
		system("unzip -o ".$api_artifilename." -d ".$DEPLOY_RUNTIME_TEMP."/EAR") == 0 or $logger->error("Unable to extract ".$api_artifilename) && exit 1;
		
		if ($config->{'config'}->{'digisign'}->{'enabled'} eq "TRUE" )
		{

			my $nexus_ds_filename = Nexus::downloadDSArtifact($logger,$DEPLOY_RUNTIME,$config,$environment);
			system("unzip -o ".$nexus_ds_filename." -d ".$DEPLOY_RUNTIME_TEMP."/DS") == 0 or $logger->error("Unable to extract ".$nexus_ds_filename) && exit 1;

			### New WAR Archive
			my $digi_war_filename = `ls $DEPLOY_RUNTIME_TEMP/EAR/egov-ap-digisignweb-*`;
			chomp $digi_war_filename;
			
			$logger->warn($digi_war_filename." ==> ".$DEPLOY_RUNTIME_TEMP."/APWAR");
			system("unzip -o ".$digi_war_filename." -d ".$DEPLOY_RUNTIME_TEMP."/APWAR") == 0 or $logger->error("Unable to extract ".$digi_war_filename) && exit 1;
			### Copy LIB contect to WEB-INF/lib
			$logger->warn("Copying lib folder to Digi-sign war under WEB-INF/lib");
			system("cp -rp ".$DEPLOY_RUNTIME_TEMP."/DS/lib/* ".$DEPLOY_RUNTIME_TEMP."/APWAR/WEB-INF/lib/.") == 0 or $logger->error("Cannot copy the Digi sign libs jar to ".$DEPLOY_RUNTIME_TEMP."/APWAR/WEB-INF/lib") && exit 1;
			
			$logger->warn("Copying Resources folder to Digi-sign war");
			system("cp -rp ".$DEPLOY_RUNTIME_TEMP."/DS/resources/* ".$DEPLOY_RUNTIME_TEMP."/APWAR/resources/.") == 0 or $logger->error("Cannot copy the Digi sign resources folder to ".$DEPLOY_RUNTIME_TEMP."/APWAR/resources") && exit 1;
			
			$logger->warn("Creating NEW WAR archive");
			my $digi_war_file = (split(/\//, $digi_war_filename))[-1];
			chdir($DEPLOY_RUNTIME_TEMP."/APWAR/");
			system("jar -cvf ".$digi_war_filename." *") == 0 or $logger->error("Unable to create new digisign war archive ==> ".$digi_war_file) && exit 1;;
			#system("cp -rp ".$digi_war_filename." ".$DEPLOY_RUNTIME_TEMP."/EAR");
			### END (New WAR Archive)
			$logger->warn("Creating NEW EAR archive");
			chdir($DEPLOY_RUNTIME_TEMP."/EAR");
			system("jar -cvf ".$DEPLOY_RUNTIME_TEMP."/".$api_artifilename." *")== 0 or $logger->error("Unable to create new EAR archive ==> ".$api_artifilename) && exit 1;
		
			$logger->warn("Replacing the EAR with Digi Sign Packaged...");
			system("cp -rp ".$DEPLOY_RUNTIME_TEMP."/".$api_artifilename." ".$DEPLOY_RUNTIME_TEMP."/../.");
		}
		
		if ( $config->{'config'}->{'cdn'}->{'enabled'} eq "TRUE" )
		{
		    cdnUpload($logger, $config, $DEPLOY_RUNTIME_TEMP."/EAR",$environment );
		}
	}
}
sub cdnUpload
{
    my ( $logger,$config, $EAR_PATH,$environment ) = @_;
    my $S3BUCKET = $config->{'config'}->{'cdn'}->{'s3.bucket'};
    my $S3_ACCESS_KEY = Decrypt::get($config->{'config'}->{'cdn'}->{'s3.accesskey'});
    my $S3_SECRET_KEY = Decrypt::get($config->{'config'}->{'cdn'}->{'s3.secretkey'});
    my $RESOURCE_FOLDER_PATH="./CDNtemp";
	my $S3_upload_list;
    my $appContextDetails = XML::Simple->new();             # initialize the object
    my $appRootContextDetails = $appContextDetails->XMLin( $EAR_PATH.'/META-INF/application.xml' );

    deploy::remove_tree($RESOURCE_FOLDER_PATH, { error => \my $err2 } );
    for my $tmp (@{ $appRootContextDetails->{module} })
    {
        mkdir ${RESOURCE_FOLDER_PATH} unless mkdir ${RESOURCE_FOLDER_PATH};
        mkdir ${RESOURCE_FOLDER_PATH}.$tmp->{web}->{"context-root"} unless -d ${RESOURCE_FOLDER_PATH}.$tmp->{web}->{"context-root"};
        system("unzip -o ".$EAR_PATH."/".$tmp->{web}->{"web-uri"}." resources/* -d ".${RESOURCE_FOLDER_PATH}.$tmp->{web}->{"context-root"});
    }
    $logger->info("Uploading the static files to S3 CDN Bucket => $S3BUCKET ...");
	system("s3cmd --access_key=${S3_ACCESS_KEY} --secret_key=${S3_SECRET_KEY} --recursive sync ${RESOURCE_FOLDER_PATH}/* $S3BUCKET --add-header='Cache-Control:max-age=31536000' --acl-public --delete-removed --guess-mime-type --no-mime-magic  --cf-invalidate --progress --no-check-md5  --delete-after");
}


sub flushrestart
{
	my($logger,$config,$environment ) = @_;
	my ($wildfly__host,$ssh);
	my $WILDFLY_HOME = "$config->{'config'}->{'wildfly'}->{'home.path'}";
	my $SSH_USER = Decrypt::get($config->{'config'}->{'wildfly'}->{'host.username'});
	my $SSH_PASS = Decrypt::get($config->{'config'}->{'wildfly'}->{'host.password'});

	foreach $wildfly__host (@{$config->{'config'}->{'wildfly'}->{'host.addr'}})
	{
		my $ssh = Net::SSH::Perl->new( $wildfly__host, port => $config->{'config'}->{'wildfly'}->{'host.ssh.port'}, priveleged => 0, options => ["UsePrivilegedPort no"]);
                #-- authenticate
                $ssh->login($SSH_USER,$SSH_PASS);
                #KILL WILDFLY
                my ($WILDFLY_PID, $stderr, $exit_status) = $ssh->cmd("ps -ef | grep -v grep | grep -i java | grep $WILDFLY_HOME | awk '{print \$2}'");
                chomp $WILDFLY_PID;
                chomp $stderr;
                chomp $exit_status;
                print $exit_status ."+".$WILDFLY_PID;
                if ( $WILDFLY_PID ne "" && $exit_status eq "0")
                {
                        my ($cmd_result, $stderr, $exit_status ) = $ssh->cmd("kill -9 $WILDFLY_PID");
                        chomp $exit_status;
                        $logger->info("Wildfly Stopped in $wildfly__host ...") if ( $exit_status == 0 );
                }
                else
                {
                        $logger->error("Unable to stop the Wildfly on $wildfly__host");
                        $logger->error("$stderr");
                        exit 1;
                }
                sleep 2;
                #REMOVE DEPLOYMENT TAG
                my ($TAG_STATUS, $stderr, $exit_status) = $ssh->cmd('sed -ie "/<deployments>.*/,/<\/deployments>/d" '.${WILDFLY_HOME}.'/standalone/configuration/standalone.xml');  
                #($TAG_STATUS, $stderr, $exit_status) = $ssh->cmd("cp -rp ${WILDFLY_HOME}/standalone/configuration/standalone-eGov-template.xml ${WILDFLY_HOME}/standalone/configuration/standalone.xml");
                if ( $exit_status eq "0" )
                {
                        $logger->warn("Removed the previous Deployment TAG from ${wildfly__host}:standalone.xml");
                }
                $ssh->cmd("rm -rf ${WILDFLY_HOME}/standalone/tmp");
                $ssh->cmd("rm -rf ${WILDFLY_HOME}/standalone/data");
                $ssh->cmd("rm -rf ${WILDFLY_HOME}/standalone/deployments/egov*");
                $logger->warn("Clean up the duplicate EAR/data/tmp directory on WILDFLY- ${wildfly__host} ...");
                $logger->info("Starting Wildfly on - ${wildfly__host} ...");
                $ssh->cmd("nohup ${WILDFLY_HOME}/bin/standalone.sh -b 0.0.0.0 > /dev/null &");
                sleep 20;
                $ssh->cmd("exit");
                #$ssh->disconnect();
 	}
}

sub validate_mgmt_status
{
	my($logger,$config,$par_template_dir,$environment,$buildnumber) = @_;
	my $WILDFLY_USERNAME = Decrypt::get($config->{'config'}->{'wildfly'}->{'mgmt'}->{'username'});
	my $WILDFLY_PASSWORD = Decrypt::get($config->{'config'}->{'wildfly'}->{'mgmt'}->{'password'});
	my $WILDFLY_MGMT_PORT = "$config->{'config'}->{'wildfly'}->{'mgmt'}->{'port'}";
	
	foreach my $wildfly_host (@{$config->{'config'}->{'wildfly'}->{'host.addr'}})
	{
		$logger->info("Verifying wildfly management service on ".$wildfly_host);
		sleep 2;
		my $WILDFLY_SERVICE_STATUS = `curl -S -H "Content-Type: application/json" -d '{"operation":"read-attribute","name":"server-state","json.pretty":1}' --digest http://${WILDFLY_USERNAME}:${WILDFLY_PASSWORD}\@${wildfly_host}:$WILDFLY_MGMT_PORT/management/ --max-time 15 -s`;
		my $e;
		eval {
		  $e = deploy::decode_json($WILDFLY_SERVICE_STATUS);
		  $WILDFLY_SERVICE_STATUS = $e->{result};
		  1;
		};
		if ( $WILDFLY_SERVICE_STATUS ne "running")
		{
			$logger->warn("Notify deployment failure.");
			$logger->error("Terminating DEPLOYMENT request, as the wildfly management service is not running on '". $wildfly_host."' host");
			Email::notify_deployment_failure($logger,$config->{'config'}->{'tenant.name'},$par_template_dir,$config,$environment,"Wildfly management service is not running on '". $wildfly_host."' host",$buildnumber, $wildfly_host); 
			exit 1;
		}
	}
}
1;
