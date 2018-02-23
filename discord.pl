use lib 'Mojo-Discord/lib';
use Mojo::Discord;
use strict;

my $discord_token = 'NDE2NDIyNjc1NDI3MDk4NjQ0.DXEPXw.pS-wFBlY_lBQ3HrxucoB8nCQa5Q';
my $discord_name = 'Rodney';
my $discord_url = "https://localhost";
my $discord_version = '1.0';
my $discord_callbacks = {'on_ready' => \&on_ready,
			 'on_message_create' => \&on_message_create};

my $discord = Mojo::Discord->new(
    'token'=>$discord_token,
    'name'=>$discord_name,
    'url'=>$discord_url,
    'version'=>$discord_version,
    'callbacks'=>$discord_callbacks,
    'reconnect'=>1,
    'verbose'=>1
    );

my $botinfo = {};

sub on_ready {
    my ($hash) = @_;
    $botinfo->{'username'} = $hash->{'user'}{'username'};
    $botinfo->{'id'} = $hash->{'user'}{'id'};

    $discord->status_update({'game' => 'NetHack 3.6.0'});
    print "Connected\n";
}

sub on_message_create {
    my ($hash) = @_;
    my $msg = $hash->{'content'};
    my $channel = $hash->{'channel_id'};

    if($channel eq "416422458195705877") {
	if($msg =~ /!gt (.)/) {
	    $discord->start_typing($channel);
	    $discord->send_message($channel, "Go Team $1!");
	}
    }
}


$discord->init();
					      
sleep(-1);
