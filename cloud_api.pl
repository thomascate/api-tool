#!/usr/bin/perl
use LWP;
use LWP::Protocol::https;
use JSON qw( decode_json );
use Getopt::Std;
use Data::Dumper;
$Data::Dumper::Indent = 1;
$|=1;

get_input();
do_auth();
format_url();
get_data();
format_output();

#basic user input with getopt, nothing fancy
sub get_input
{
  getopts('k:u:p:c:C:hr:',\%opt);

  if ($opt{'h'}){
    do_usage();
  }

  if ($opt{'p'}){
    $product = "$opt{'p'}";
  }
  else{
    $product = 'cloudServers';
  }

  if ($opt{'c'}){
    $check = "$opt{'c'}";
  }
  else{
    $check = 'limits';
  }
  
  if ($opt{'k'}){
    $api_key = "$opt{'k'}";
  }
  else{
    do_usage();
  }
  
  if ($opt{'u'}){
    $username = "$opt{'u'}";
  }
  else{
    do_usage();
  }
  
  if ($opt{'r'}){
    $region = "$opt{'r'}";
    $region = lc($region);
    $ucregion = uc($region);
  }
  else{
    $region = "all";
  }

  if ($opt{'C'}){
    $container = "$opt{'C'}";
  }
}

#Auth pulls the users auth_token, as well as their service catalog, serviceCatalog is a hash reference that contains all services, locations and public urls
sub do_auth
{
  my $auth_url = 'https://auth.api.rackspacecloud.com/v1.1/auth';
  my $auth_json =  '{"credentials":{"username":"' . $username . '","key":"' . $api_key . '"}}';
  my $auth_request = HTTP::Request->new( 'POST', $auth_url ) ;
  $auth_request->header( 'Content-Type' => 'application/json' );
  $auth_request->content( $auth_json );

  my $auth_lwp = LWP::UserAgent->new;
  my $auth_content = $auth_lwp->request( $auth_request );
  my $response_code = $auth_content->status_line, "\n";

  if ($response_code eq '200 OK'){

    $auth_content = $auth_content->decoded_content;
#  print Dumper($auth_content);
    $auth_content = decode_json( $auth_content );

    $auth_token = $auth_content->{'auth'}{'token'}{'id'};
    $auth_expires = $auth_content->{'auth'}{'token'}{'expires'};

    $service_catalog = $auth_content->{'auth'}{'serviceCatalog'};

#  print Dumper($service_catalog);
#  print "$username, $api_key\n";
#print Dumper($auth_content);

    return ($auth_token, $auth_expires, $service_catalog);
  }
  else{
    print "$response_code\n";
    if ($auth_content->{'_content'} =~ /Username\sor\sapi\skey\sis\sinvalid/){
      print "Username or api key is invalid\n";
    }
    else{
      print Dumper($auth_content);
    }
    exit 1;
  }

}

#since there doesn't seem to be a standard format for this we have to manually yank each one out of service_catalog, yuck
sub format_url {
#  print Dumper($service_catalog);
  if ($product eq 'cloudServers'){
    if ($check eq 'limits'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/limits';
    }
    if ($check eq 'servers'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/servers';
    }
    if ($check eq 'servers-detail'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/servers/detail';
    }
    if ($check eq 'images'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/images';
    }
    if ($check eq 'images-detail'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/images/detail';
    }
    if ($check eq 'sharedip'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/shared_ip_groups';
    }
    if ($check eq 'sharedip-detail'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/shared_ip_groups/detail';
    }
  }


  if ($product eq 'cloudServersOpenStack'){
     if ($check eq 'servers-detail'){
       $check = 'servers/detail';
     }

     if ($check eq 'images-detail'){
       $check = 'images/detail';
     }

     if ($check eq 'images-full-detail'){
       $check = 'images/detail';
       $full_detail = 1;
     }

     if ($check eq 'flavors-detail'){
       $check = 'flavors/detail';
     }

     if ($region eq 'all'){
       multi_region();
     }

     else{
       single_region();
     }
  }

  if ($product eq 'cloudMonitoring'){
    if ($check eq 'limits'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/limits';
    }
    if ($check eq 'entities'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/entities';
    }
    if ($check eq 'notifications'){
      $public_url = $service_catalog->{$product}[0]{'publicURL'} . '/notifications';
    }
  }



  if ($product eq 'cloudLoadBalancers'){
    if ($check eq 'limits'){
      $check = 'loadbalancers/limits';
    }

    if ($check eq 'absolute-limits'){
      $check = 'loadbalancers/absolute-limits';
    }


    if ($check eq 'loadbalancers'){
      $check = 'loadbalancers';
    }

    if ($region eq 'all'){
      multi_region();
    }
    else{
      single_region();
    }
  }






  if ($product eq 'cloudFiles'){
    if (($check eq 'containers')||($check eq 'containers-detail')){
      if ($region eq 'all'){
        multi_region();
      }
      else{
        single_region();
      }

    }
  }

  if ($product eq 'cloudFilesCDN'){ 
    if (($check eq 'containers')||($check eq 'containers-detail')){
      if ($region eq 'all'){
        multi_region();
      }
      else{
        single_region();
      }
    }
  }

#cloudDatabases calls get_data and format_output directly, this is due to the code that handles the multiple addresses.
  if ($product eq 'cloudDatabases'){
    if ($region eq 'all'){
      multi_region();
    }
    else{
      single_region();
    }


  }
 return ($public_url);
}

#Here we're actually doing the get request and shoving everything we get back as a hash refrence in $content
sub get_data
{
  my $get_request = HTTP::Request->new( 'GET', $public_url );


#  $get_request->header( 'X-Auth-Token' => $auth_token );
#  print "'$auth_token'\n";
  $get_request->header( 'X-Auth-Token',$auth_token );
  my $get_lwp = LWP::UserAgent->new;
#  $content = ();


  $content = $get_lwp->request( $get_request );

  $content = $content->decoded_content;

#  print "$public_url\n$auth_token\n";
#  print Dumper($content);

    $content = decode_json( $content );
#  print Dumper($content);

  return ($content);
}


#this is mostly jacking with $content to pull out the data we need for each option. Since there doesn't seem to be much standardization this code is not very general. Oh well.
sub format_output {
  print "\n\ncurl -XGET -H \"X-AUTH-Token: $auth_token\" $public_url \| python -mjson.tool\n";

######################### 1st Gen Cloud Servers #########################
  if ($product eq 'cloudServers'){

    if ($check eq 'limits'){
      #this is chopping up the decoded json, so I'm not dealing with hashes of hashes of hashes...
      my $absolutes = $content->{'limits'}{'absolute'};
      my $rates = $content->{'limits'}{'rate'};
      print "\nAbsolute\n";

#      print Dumper($absolutes);

      #iterate through the hashes spitting out the key/value pairs, printf for the keys to make nice collumns
      while( my ($key, $value) = each %$absolutes ){
        printf ("%-20s","  $key");
        print "$value\n";
      }
      print "\nrates\n";

      foreach (@$rates) {
      print "\n";
        while( my ($key, $value) = each %$_ ){
          printf ("%-20s","  $key");
          print "$value\n";
        }
      }

    }


    if ($check eq 'servers'){
      my $servers = $content->{'servers'};

      foreach (@$servers) {
        print "\n";
        while( my ($key, $value) = each %$_ ){
          printf ("%-20s","  $key");
          print "$value\n";
        }
      }
    }

    if ($check eq 'servers-detail'){
      my $servers = $content->{'servers'};
      $i=0;
      foreach (@$servers) {
        print "\n\n";
        while( my ($key, $value) = each %$_ ){
          if ($key eq 'addresses'){
            my $publics  = $servers->[$i]{'addresses'}{'public'};
            my $privates = $servers->[$i]{'addresses'}{'private'};
            print "  Public Addresses:\n";
            foreach (@$publics){
              print "    $_\n";
            }
            print "  Private Addresses:\n";
            foreach (@$privates){
              print "    $_\n";
            }
         }
         elsif ($key eq 'metadata'){
           my $metadata_id = $servers->[$i]{'metadata'}{'id'};
           print "  Meta Data:\n";
           foreach (@$metadata_id){
             print "    $_\n";  
           }          
         }
         else{
            printf ("%-20s","  $key");
            print "$value\n";
          }
        }
        $i++;
      }
    }

   if (($check eq 'images')||($check eq 'images-detail')){
     my $images = $content->{'images'};
      foreach (@$images) {
        print "\n";
        while( my ($key, $value) = each %$_ ){
          printf ("%-20s","  $key");
          print "$value\n";
        }
      }
   }

  }




######################### 2nd Gen Cloud Servers #########################
  if ($product eq 'cloudServersOpenStack'){

    if ($check eq 'limits'){

      print "\n$current_region\n";
      my $absolutes = $content->{'limits'}{'absolute'};
      my $rates = $content->{'limits'}{'rate'};
      print "\nAbsolute\n";

      while( my ($key, $value) = each %$absolutes ){
        printf ("%-30s","  $key");
        print "$value\n";
      }
      print "\nrates\n";

      $j=0;
      foreach (@$rates) {

#        print "\n";

        $current_rate = $rates->[$j]{'limit'};

        $k=0;
        foreach (@$current_rate){
          my $temporary_hash_ref = $current_rate->[$k];
          while( my ($limit_key, $limit_value) = each %$temporary_hash_ref ){

             printf ("%-30s","  $limit_key");
             print "$limit_value\n";

          }
        $k++;
#        print "\n";
        printf ("%-30s","  regex ");
        print $rates->[$j]{'regex'},"\n";
        printf ("%-30s","  uri ");
        print $rates->[$j]{'uri'},"\n\n";
        }
     $j++;
     }
    }


    if ($check eq 'servers'){

      print "\n$current_region\n";
 
      my $servers = $content->{'servers'};

      foreach (@$servers) {
        print "\n";
        while( my ($key, $value) = each %$_ ){
          unless(($key eq 'links')||($key eq 'metadata')){
            printf ("%-20s","  $key");
            print "$value\n";
          }
        }
      }

    }

    if ($check eq 'servers/detail'){
      print "\n$current_region\n";
      my $servers = $content->{'servers'};
      $j=0;
      foreach (@$servers) {
        print "\n\n";
        while( my ($key, $value) = each %$_ ){

            if (($key eq 'flavor')||($key eq 'image')){
              printf ("%-30s","  $key");
              print $servers->[$j]{$key}{'id'},"\n";
            }

            elsif ($key eq 'addresses'){
              my $publics  = $servers->[$j]{'addresses'}{'public'};
              my $privates = $servers->[$j]{'addresses'}{'private'};
              print "  Public Addresses:\n";
              $k=0;
              foreach (@$publics){
                printf ("%-32s","    IPV$publics->[$k]{'version'}");
                print $publics->[$k]{'addr'},"\n";
                $k++;
              }
              print "  Private Addresses:\n";
              $k=0;
              foreach (@$privates){
                printf ("%-32s","    IPV$privates->[$k]{'version'}");
                print $privates->[$k]{'addr'},"\n";
                $k++;
              }
            }

            elsif (($key eq 'metadata')||($key eq 'links')||($key eq 'rax-bandwidth:bandwidth')||($key eq 'accessIPv4')||($key eq 'accessIPv6')){
              break;
            }

            else{
              printf ("%-30s","  $key");
              print "$value\n";
            }
        }
        print "  Public Bandwidth:\n";
        $bandwidth = $servers->[$j]{'rax-bandwidth:bandwidth'}['0'];
        while( my ($band_key, $band_value) = each %$bandwidth){
              printf ("%-32s","    $band_key");
              print $servers->[$j]{'rax-bandwidth:bandwidth'}['0']{$band_key},"\n";
        }

        print "  Private Bandwidth:\n";
        $bandwidth = $servers->[$j]{'rax-bandwidth:bandwidth'}['0'];
        while( my ($band_key, $band_value) = each %$bandwidth){
              printf ("%-32s","    $band_key");
              print $servers->[$j]{'rax-bandwidth:bandwidth'}['1']{$band_key},"\n";
        }



        $j++;
      }
    }
  
    if (($check eq 'images')||($check eq 'images/detail')){
     print "\n$current_region\n";
     my $images = $content->{'images'};
      foreach (@$images) {
        print "\n";
        while( my ($key, $value) = each %$_ ){
          unless(($key eq 'links')||($key eq 'metadata')){
            printf ("%-20s","  $key");
            print "$value\n";
          }
        }

        if ($full_detail == 1){
          my $metadata = $_->{'metadata'};
          printf ("%-20s","  Metadata:");
          print "\n";
          while ( my ($metakey, $metavalue) = each(%$metadata) ){
            printf ("%-50s","    $metakey");
            print "$metavalue\n";
          }
          my $metadata = ();
        }
      }
    }

    if (($check eq 'flavors')||($check eq 'flavors/detail')){
      print "\n$current_region\n";

      $flavors = $content->{'flavors'};
      foreach (@$flavors) {
        print "\n";
        while( my ($key, $value) = each %$_ ){
          unless(($key eq 'links')||($key eq 'OS-FLV-DISABLED:disabled')){
            printf ("%-20s","  $key");
            print "$value\n";
          }
        }
      }
    }


  }


######################### Load Balancers #########################
  if ($product eq 'cloudLoadBalancers'){

  #  print Dumper($content);
    if ($check eq 'loadbalancers'){

##### WORKING HERE
print Dumper($content); 
      print "\n$current_region\n";
      $lbs = $content->{'loadBalancers'};
      foreach (@$lbs){
        print "\n";
        while( my ($key, $value) = each %$_ ){

          if ($key eq "created"){
            printf ("%-20s","  $key");
            print $value->{'time'},"\n";
          }
          elsif ($key eq "updated"){
            printf ("%-20s","  $key");
            print $value->{'time'},"\n";
          }
          elsif ($key eq "virtualIps"){
            printf ("%-30s","  ipVersion");
            print $value->{'virtualIps'}{'ipVersion'}[0],"\n";
#            printf ("%-30s","  type");
#            print $value->{'type'},"\n";
#            printf ("%-30s","  id");
#            print $value->{'id'},"\n";
#            printf ("%-30s","  address");
#            print $value->{'address'},"\n";
          }
          
          
          
          
          
          
          else{
            printf ("%-20s","  $key");
            print "$value\n";
          }
        }
#      print "\n";

      }

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 ##### working here     
    }



  }










######################### Cloud Monitoring #########################
  if ($product eq 'cloudMonitoring'){

    if ($check eq 'limits'){
      my $absolutes = $content->{'resource'};
      my $rates = $content->{'rate'};
      print "\nAbsolute\n";

      while( my ($key, $value) = each %$absolutes ){
        printf ("%-20s","  $key");
        print "$value\n";
      }
      print "\nRates\n\n";

      while( my ($key1, $value1) = each %$rates){  
	print "$key1\n";
        while( my ($key, $value) = each %$value1 ){
          printf ("%-20s","  $key");
          print "$value\n";
        }
        print "\n";
      }

    }

    if ($check eq 'monitors'){

      print Dumper($content);

    }

    if ($check eq 'notifications'){

    print Dumper($content);

    }

  }


  if ($product eq 'cloudDatabases'){

    if ($check eq 'instances'){

      print "\n$current_region\n";
#       print $sites->[$i]{'region'},"\n";
#      print Dumper($content);
      $instances = $content->{'instances'};
      foreach (@$instances){

        print "\n";
        while( my ($key, $value) = each %$_ ){
          if ($key eq "volume"){
            printf ("%-20s","  $key");
            print $value->{'size'},"\n";
          }
          elsif ($key eq "flavor"){
            printf ("%-20s","  $key");
            print $value->{'id'},"\n";
          }
          else{
            printf ("%-20s","  $key");
            print "$value\n";
          }
        }
      print "\n";

      }

      print "\n";

    }

    if ($check eq 'flavors'){

      $flavors = $content->{'flavors'};

      print "\n$current_region\n";
      foreach (@$flavors) {
        print "\n";
        while( my ($key, $value) = each %$_ ){
          printf ("%-20s","  $key");
          print "$value\n";
        }
      }
    }

  }




######################### Cloud Files #########################
  if ($product eq 'cloudFiles'){
    unless ($container eq '') {
      ($base_url)=(split(/\?format=json/,$public_url));
      print "\nContainer: $container\n\n";
      START:
      foreach $object (@$content) {
        $object_count++;
        $loop_count++;
        print "$object_count\t", $object->{'name'},"\t", $object->{'last_modified'},"\t", $object->{'bytes'},"\t", $object->{'content_type'},"\n";
        if ("$loop_count" eq '10000') {
          $marker = $object->{'name'};
          $loop_count='';
          $public_url = "$base_url?marker=$marker\&format=json";
          get_data();
          goto START;        
        }
      }
    }
    else { 
      if ($check eq 'containers'){

         print "\n$current_region\n\n";
         if (@$content){
           foreach (@$content){
             print "  ",$_->{'name'},"\n";
           }
         }
         else{
           print "no content\n";
           exit 1;
         }
         print "\n";
      }

       if ($check eq 'containers-detail'){
          print "\n$current_region\n\n";
 
          foreach (@$content){
            print "\n";

            printf ("%-20s","name"); 
            print $_->{'name'},"\n";
            printf ("%-20s","count");
            print $_->{'count'},"\n";
            printf ("%-20s","bytes");
            print $_->{'bytes'},"\n"; 

            print "\n";
          }

       }


    }
  }
  

######################### Cloud CDN #########################
if ($product eq 'cloudFilesCDN') {
    unless ($container eq '') {
      ($base_url)=(split(/\?format=json/,$public_url));
      print "\nContainer: $container\n\n";
      START:
      foreach $object (@$content) {
        $object_count++;
        $loop_count++;
        print "$object_count\t", $object->{'name'},"\t", $object->{'last_modified'},"\t", $object->{'bytes'},"\t", $object->{'content_type'},"\n";
        if ("$loop_count" eq '10000') {
          $marker = $object->{'name'};
          $loop_count='';
          $public_url = "$base_url?marker=$marker\&format=json";
          get_data();
          goto START;        
        }
      }
    }
    else { 
      if ($check eq 'containers'){

         print "\n$current_region\n\n";
         if (@$content){
           foreach (@$content){
             print "  ",$_->{'name'},"\n";
           }
         }
         else{
           print "no content\n";
           exit 1;
         }
         print "\n";
      }

       if ($check eq 'containers-detail'){
          print "\n$current_region\n\n";
 
          foreach (@$content){
            print "\n";

            printf ("%-20s","name"); 
            print $_->{'name'},"\n";
            printf ("%-20s","ttl");
            print $_->{'ttl'},"\n";
            printf ("%-20s","http");
            print $_->{'cdn_uri'},"\n"; 
            printf ("%-20s","https");
            print $_->{'cdn_ssl_uri'},"\n"; 
            printf ("%-20s","streaming");
            print $_->{'cdn_streaming_uri'},"\n"; 
            printf ("%-20s","enabled"); 
            print $_->{'cdn_enabled'},"\n";
     
            print "\n";
          }

       }


    }
  }  
  

}








sub multi_region {

    if ($region eq 'all'){

      $sites = $service_catalog->{$product};
#      print Dumper($sites);

      $i = 0;
      foreach (@$sites){

        if ( ($product eq 'cloudFiles') || ($product eq 'cloudFilesCDN') ) {
          unless ($container eq '') {
            $public_url = $sites->[$i]{'publicURL'} . '/' . $container . '?format=json';
          }
          else {     
            $public_url = $sites->[$i]{'publicURL'} . '?format=json';
          }
        }
        else{
          $public_url = $sites->[$i]{'publicURL'} . '/' . $check;
        }

        $current_region = $sites->[$i]{'region'};
#        print "$current_region\n$public_url\n";
        get_data();
        format_output();
        $i++;
      }

      exit 0;
    }

}


sub single_region {
    $sites = $service_catalog->{$product};
    $i = 0;
#print "Sites: $sites\n";
    foreach (@$sites){
#print Dumper($content);
#print "X: $sites[$i]\n";
#print "$region\n"; 
#$printpub = "$public_url = $sites->[$i]{'publicURL'}"; 
#print "$printpub\n";
      if ( ($product eq 'cloudFiles') || ($product eq 'cloudFilesCDN') ) {
        unless ($container eq '') {
          $public_url = $sites->[$i]{'publicURL'} . '/' . $container . '?format=json';
        }
        else {     
          $public_url = $sites->[$i]{'publicURL'} . '?format=json';
        }
      }
      else {
        $public_url = $sites->[$i]{'publicURL'} . '/' . $check;
      }
      if ($public_url =~ m/$region/) {
        $found_region = 1;
        get_data();
        format_output();
      }
      $i++;
    }

   if (( $found_region == 0 ) && ( $region ne 'all')){
      print "Region not found\n";
    }
  exit 0;
}

sub do_usage
{
 print "This script is still in development, email thomas.cate\@rackspace.com with any questions\n\n";
 print "necessary flags\n";
 print "-u cloud account username\n";
 print "-k cloud account api-key\n\n";
 print "optional flags\n";
 print "-p product\n";
 print "  cloudServers (default)\n";
 print "  cloudServersOpenStack\n";
 print "  cloudMonitoring (partially implemented)\n";
 print "  cloudDatabases\n";
 print "  cloudDNS (not implemented)\n";
 print "  cloudFilesCDN\n";
 print "  cloudLoadBalancers\n";
 print "  cloudFiles\n\n";
 print "-r region, region you're checking against\n";
 print "  ALL, (default)\n";
 print "  ORD, Chicago\n";
 print "  DFW, Dallas\n";
 print "  SYD, Sydney\n\n";
 print "-c check, these flags vary by product\n";
 print "  cloudServers:\n";
 print "    limits, check api absolute and rate limits\n";
 print "    servers, brief summary of servers\n";
 print "    servers-detail, detailed view of servers\n";
 print "    images, all available images on the account\n";
 print "    images-detail, detail view of server images\n";
 print "    sharedip, (not implemented)\n";
 print "    sharedip-detail, (not implemented)\n";
 print "  cloudServersOpenStack:\n";
 print "    limits, check api absolute and rate limits\n";
 print "    servers, brief summary of servers\n";
 print "    servers-detail, detailed view of servers\n";
 print "    images, all available images on the account\n";
 print "    images-detail, detail view of server images\n";
 print "    images-full-detail, full detail with metadata\n";
 print "  cloudMonitoring:\n";
 print "    limits, check api absolute and rate limits\n";
 print "    entities, (partially implemented, data dumper\n"; 
 print "    notifications, (partially implemented, data dumper\n";
 print "  cloudDatabases:\n";
 print "    instances, show all databases on account\n";
 print "    flavors, show available flavors on account\n";
 print "  cloudFiles:\n";
 print "    containers, list all containers on your account\n";
 print "    containers-detail, detailed container list\n"; 
 print "  cloudFilesCDN:\n";
 print "    containers, list all containers on your account\n";
 print "    containers-detail, detailed container list\n";
 print "  cloudLoadBalancers:\n";
 print "    limits, check api rate limits\n";
 print "    absolute-limits, check absolute limits\n";
 print "    loadbalancers, summary of loadbalancers\n";
 print "    loadbalancers-detail, detailed listing of loadbalancers\n";
 print "    loadbalancers-full-detail, list everything, nodes, virtuals etc\n";
 print "    usage, current account usage\n";
 print "    caching, show content caching\n";
 print "    protocols, list load balancing protocols\n";
exit 0;
}
