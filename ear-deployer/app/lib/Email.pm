=head
# ##################################
# 
# Module : Email.pm
#
# SYNOPSIS
# Send email events on deployment status.
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
package Email;

use strict;
use FindBin;


sub notify_deployment_failure
{
	my ( $logger,$TENANT_NAME,$par_template_dir,$config,$environment,$failure_message,$buildnumber, $hostname, $deploy_failure) = @_;
	my $YEAR = `date +%Y`;
	my $DATE = `date`;
	chomp $YEAR;
	chomp $TENANT_NAME;
	chomp $environment;
	$TENANT_NAME="eGov Productization" if ( $TENANT_NAME eq "" );
	$failure_message = "<b>Reason for Failure : </b>".$failure_message;
	my $tmpl = HTML::Template->new( filename => $par_template_dir.'/failed_template.tmpl' );
	$tmpl->param(
   					year     		=> $YEAR,
   					HOSTNAME		=> " on <b>".$hostname."</b>",
   					DEPLOY_FAIL_LOG => $failure_message,
   					deploy_status	=> '<a style="color:#FFFFFF;text-decoration:none;font-family:Helvetica,Arial,sans-serif;font-size:20px;line-height:135%;"><strong>FAILED</strong></a>'
				);
	Email::sendMail("( #".$buildnumber." ) Deployment of ".$TENANT_NAME." failed on ".uc($environment)." environment.",$tmpl->output, $config, $logger,$deploy_failure);

}

sub notify_deployment_success
{
	my ( $logger,$TENANT_NAME,$par_template_dir,$config,$snapshot_details,$environment,$buildnumber ) = @_;
	my $YEAR = `date +%Y`;
	my $DATE = `date`;
	my ($API_SCM_HASH,$API_SCM_BRANCH,$api_artifilename,$api_arti_version,$api_git_url) = (split /::/, $snapshot_details);
	chomp $YEAR;
	chomp $TENANT_NAME;
	chomp $environment;
	$TENANT_NAME="eGov Productization" if ( $TENANT_NAME eq "" );
	$api_git_url = `echo $api_git_url | awk -F "\@" '{print \$NF}'| rev | cut -d. -f2- | rev`;	
	$api_git_url =~ s/:/\//g;
	my $tmpl = HTML::Template->new( filename => $par_template_dir.'/success_template.tmpl' );
	$tmpl->param(
   					year     		=> $YEAR,
   					artifact 		=> $api_artifilename,
   					version			=> $api_arti_version,
   					sha				=> "<a href=\"http://".${api_git_url}."/commit/".$API_SCM_HASH."\" target='_blank'>".substr($API_SCM_HASH, 0, 8)."</a>",
   					branch			=> $API_SCM_BRANCH,
   					deploy_status	=> '<a style="color:#FFFFFF;text-decoration:none;font-family:Helvetica,Arial,sans-serif;font-size:20px;line-height:135%;"><strong>SUCCESSFUL</strong></a>'
				);
	Email::sendMail("( #".$buildnumber." ) Deployment of ".$TENANT_NAME." successful on ".uc($environment)." environment.",$tmpl->output, $config, $logger);
}

sub notify_deployment_alert
{
	my ( $logger,$par_template_dir,$environment,$config,$buildnumber) = @_;
	
	my $YEAR = `date +%Y`;
	my $DATE = `date`;
	my $TENANT_NAME = $config->{'config'}->{'tenant.name'};
	chomp $YEAR;
	chomp $TENANT_NAME;
	chomp $buildnumber;
	chomp $environment;
	$TENANT_NAME="eGov Productization" if ( $TENANT_NAME eq "" );
	my $mail_sub = "Deploying ".$TENANT_NAME." build (#".${buildnumber}.") to ".uc($environment);
	my $tmpl = HTML::Template->new( filename => $par_template_dir.'/notify_template.tmpl' );
	$tmpl->param(
   					year     	=> $YEAR,
   					buildnumber => $buildnumber,
   					jenkinsURL	=> $config->{'config'}->{'jenkins'}->{'url'},
   					DATE		=> $DATE
				);
	Email::sendMail($mail_sub, $tmpl->output, $config, $logger);
}

#sub notify_deployment_alert
#{
#	my ( $logger, $TENANT_NAME, $par_template_dir, $environment, $baseConfigFile, $buildnumber) = @_;
#	
#	my $YEAR = `date +%Y`;
#	chomp $YEAR;
#	my $tmpl = HTML::Template->new( filename => $par_template_dir.'/notify_template.tmpl' );
#	$tmpl->param(
#   					year     	=> $YEAR,
#   					buildnumber => $buildnumber
#				);
#	#Email::sendMail(uc($environment)." deployment initiated on AP Productization",$tmpl->output, $baseConfigFile, $logger);
#	Email::sendMail("Deployment of ".$TENANT_NAME." to ".uc($environment)." initiated.",$tmpl->output, $baseConfigFile, $logger);
#}

sub sendMail
{
	
    my ($mail_subject, $mail_body , $config, $logger, $deploy_failure) = @_;
    $mail_subject = Encode::decode('utf-8',"ⓓⓔⓥⓞⓟⓢ").' '.$mail_subject;
    my $SMTP_HOST = $config->{'smtp'}->{'hostname'};
    my $SMTP_PORT = $config->{'smtp'}->{'port'};
    my $SMTP_USERNAME = Decrypt::get($config->{'smtp'}->{'username'});
    my $SMTP_PASSWORD = Decrypt::get($config->{'smtp'}->{'password'});
    my $mail_to_list = $config->{'smtp'}->{'receivers'};
    #$mail_to_list = 'egov-systems@egovernments.org';       
    my @mail_to = split (',',$mail_to_list);
    
    my $smtp;
    my $boundary = "eGOV-DEPLOYMENT";
    
	if (not $smtp = Net::SMTP::SSL->new($SMTP_HOST, Port => $SMTP_PORT)) {
	   $logger->error( "Could not connect to smtp server.");
	}
		
	$smtp->auth($SMTP_USERNAME, $SMTP_PASSWORD) || print "Gmail authentication failed! \n";
	$smtp->mail($SMTP_USERNAME . "\n");
	$smtp->recipient(@mail_to, { SkipBad => 1 });
	
	$smtp->data();
	$smtp->datasend("From: DevOps Support <" . $SMTP_USERNAME . ">\n");
	$smtp->datasend("To:" . $mail_to_list . "\n");
	$smtp->datasend("Importance: high\n");
	$smtp->datasend("Subject: ".Encode::encode('MIME-Header',$mail_subject)."\n");
	$smtp->datasend("MIME-Version: 1.0\n");
	$smtp->datasend("Content-type: multipart/mixed;\n\tboundary=\"$boundary\"\n");
	$smtp->datasend("\n");
	$smtp->datasend("\n--$boundary\n");
	$smtp->datasend("Content-type: text/html;charset=\"UTF-8\" \n");
	$smtp->datasend("\n");
	$smtp->datasend($mail_body . "\n");
	$smtp->datasend("\n");
	$smtp->datasend("\n--$boundary\n");
	
	if ( $deploy_failure ne "" )
	{
		$smtp->datasend("Content-Disposition: attachment; filename=\"$deploy_failure\"\n");
		$smtp->datasend("Content-Type: application/text; name=\"$deploy_failure\"\n");
		$smtp->datasend("\n");
		open CSVFH, "< $deploy_failure";
		while (<CSVFH>) { chomp; $smtp->datasend("$_\n"); }
		close CSVFH;
		$smtp->datasend("\n");
		$smtp->datasend("--$boundary\n");
	}
	$smtp->dataend();
	$smtp->quit;
}
1;
