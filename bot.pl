#!/usr/bin/perl
use warnings;
use strict;
use integer;
use POE;
use POE::Component::IRC;
use Net::Google;
use WWW::Wikipedia;
use constant LOCAL_GOOGLE_KEY => "PqCJzeJQFHL/2AjeinchN3PyJoC2xUaM";

use DBI;
# database should como from the config file TODO
my $dbh = DBI->connect("dbi:SQLite:dbname=bot.db","","");
#should go in the conffile too
my $logfile = "./foobot.log";
#open(LOG,">>$logfile") || die("This file will not open!");
sub CHANNEL () { "#rm-bot" }

my ($irc) = POE::Component::IRC->spawn();

POE::Session->create(
    inline_states => {
        _start     => \&bot_start,
        irc_001    => \&on_connect,
        irc_public => \&on_public,
    },
);

# The bot session has started.  Register this bot with the "magnet"
# IRC component.  Select a nickname.  Connect to a server.
sub bot_start {
    my $kernel  = $_[KERNEL];
    my $heap    = $_[HEAP];
    my $session = $_[SESSION];

    $irc->yield( register => "all" );

    #my $nick = 'usepoe' . $$ % 1000;
# nick and alternative nick and params should go in a config file
	$irc->yield( connect =>
          { Nick => 'foobot',
            Username => 'foobot',
            Ircname  => 'Fooberto',
            Server   => 'localhost',
            Port     => '6667',
          }
    );
}

# The bot has successfully connected to a server.  Join a channel.
sub on_connect {
    $irc->yield( join => CHANNEL );
}

# The bot has received a public message.  Parse it for commands, and
# respond to interesting things.
sub on_public {
    my ( $kernel, $who, $where, $msg ) = @_[ KERNEL, ARG0, ARG1, ARG2 ];
    my $nick = ( split /!/, $who )[0];
    my $channel = $where->[0];

   # print ouput to screen and also log it
    my $ts = scalar localtime;
    print " [$ts] <$nick:$channel> $msg\n";
#chanlog
    &chanlog(" [$ts] <$nick:$channel> $msg");
# catch users correcting words
    &correctuser($msg, $nick);
#log at sqlite to (FIXME use the same function)
    &dblog("$nick", "$msg");
    
# karma catcher
    &karmacatch($nick, $msg);
    # capture command char (also this should go on the config file)
    my $commandchar = "@";
# not using ^^^^ yet should be, TODO

    if ( ($msg =~ m/^@/) || ($msg =~ m/^foobot(,|;|:).+/ ) ) {
	#default'ing usenick, I know, is ugly FIXME
	my $usenick = 'no';
	$usenick = "yes" if $msg =~ m/^foobot(,|;|:).+/;
	$msg =~ s/(^@|^foobot(,|;|:)\s+)//;
	# Commands come whit the 	
	
	for ($msg) {
		#default ping command
		if ($msg =~ m/ping/i) {
			#$irc->yield( privmsg => CHANNEL, "hola $nick");
			&say("pong!", $nick, $usenick);
		}
		# fortune cookies
		elsif ($msg =~ m/fortune/i) {
		    my $out = &fortune();
		    &say($out, $nick, $usenick);
		}
		elsif ($msg =~ m/google/i) {
		   $msg =~ s/google//i;
		   if (length($msg) >= 1) {
		        my $out = &google($msg);
			&say($out, $nick, $usenick);
		   }
		}
		elsif ($msg =~ m/decifrar/i) {
		   $msg =~ s/decifrar//i;
		   if (length($msg) >= 1) {
		        my $out = &decifrar($msg);
			if ($out) {
			    &say($out, $nick, $usenick);
			} else {
			   &say("no soy perfecto, pero creo que $msg esta bien", $nick, $usenick);
			}
		   }
		}
		elsif ($msg =~ m/definir/i) {
		   $msg =~ s/definir//i;
		   if (length($msg) >= 1) {
		        my $out = &definir($msg);
			if ($out) {
			    &say($out, $nick, $usenick);
			} else {
			   &say("err, no encontre $msg", $nick, $usenick);
			}
		   }
		}
		elsif ($msg =~ m/visto/i) {
		   $msg =~ s/visto//i;
		   if (length($msg) >= 1) {
			$msg =~ s/\ +//g;
			my @seen = &dbuexist($msg);
			if ($seen[0]) {
			    my $msout = "Parece que $msg, andaba aquí el $seen[0], lo último que salio de su teclado fue $seen[1]";
			    &say($msout, $nick, $usenick);
			} else {
			   &say("ese ser mitologico núnca entro a este antro de perdición", $nick, $usenick);
			}
		   }
		}
		elsif ($msg =~ m/karma/i) {
		   $msg =~ s/karma//i;
		   if (length($msg) >= 1) {
			$msg =~ s/\ +//g;
			my @seen = &dbuexist($msg);
			if ($seen[0]) {
			    #my $msout = "Parece que $msg, andaba aquí el $seen[0], lo último que salio de su teclado fue $seen[1]";
			    #&say($msout, $nick, $usenick);
			    my $karma = &getkarma($msg);
			    if ($karma < 0 ) {
				    &say("ese tal $msg esta mal, $karma", $nick, $usenick);
			    } elsif ( $karma > 0) { 
				    &say("parece que $msg se porta bien, $karma", $nick, $usenick);
			    } elsif ( $karma == 0 ) { &say("creo que $msg es _neutral_ , $karma", $nick, $usenick); }
			} 
		   }
		}
		elsif ($msg =~ m/aprender que.+es.+/i) {
		   $msg =~ s/aprender//i;
		   my $fact = $msg;
		   my $fulltext = $msg;
		   $fact =~ s/(que\ )|(\ es.+)//g;
		   $fact =~ s/\ +//g;
		   $fulltext =~ s/(que.+$fact.+es)//g;

		   if ((length($fact) >= 1) and (length($fulltext)>=1)) {
			my $getfact = &fffact("$fact");
			if (!$getfact) {
			   &putfact("$fact", "$fulltext", "$nick");
			}
		    } 
		   
		}
		elsif ($msg =~ m/olvidar/i) {
		   $msg =~ s/olvidar//i;
		   $msg =~ s/\ +//g;
		   if (length($msg) >= 1) {
			   my $isfact = &fffact("$msg");
			   if ($isfact) {
			   	&forgetfact($msg) # unless( !$isfact);
			   }
		   }
		}
		else {  
			$msg =~ s/\ +//g;
			my $isfact = &fffact("$msg");
			if (!$isfact) {
				my $foo = 'no';
				#$irc->yield( privmsg => CHANNEL, "$msg.- comando no existe"); 
			} else {
				my @randmsg = ("según me comentaron", "en la calle escuche rumores que dicen que", 
				"dicen las malas lenguas que", "
				yo alguna vez escuche que", "a mi alguien me dijo que", "todos dicen que");
				my $random = rand(@randmsg);
				$random*=1;
				&say("$randmsg[$random] $msg es $isfact", $nick, $usenick); 

			}
		}
	}
    }

}

# this is totaly *WRONG* this is a bad approch, /me should not try to write
# code when is a kind of drunk
sub correctuser {
# Add a check if the user exists even if try to use the regexp->FIXME
	my ($msg, $nick) = @_;
	if ($msg =~ m/s\/.+\/$/) {
	    my $sth = $dbh->prepare
	        ("SELECT last from users where nick='$nick'");
	    $sth->execute();
	    my $rowi = $sth->fetchrow;
	    $msg =~ s/^s//;
	    my @chan = split(/\//, $msg);
	    $rowi =~ s/$chan[1]/$chan[2]/g;
	    &say("$nick en realidad quería decir \"$rowi\"", $nick, "no");
      }
}

sub forgetfact {
	my $dfact = shift;
	my $sth = $dbh->prepare
	    ("SELECT rowid from facts where fact='$dfact'");
	$sth->execute();
	my $row = $sth->fetchrow;
	$dbh->do("DELETE from facts where rowid='$row'");

}

sub putfact {
	my ($fact, $fulltext, $nick) = @_;
	my $sth = $dbh->prepare("INSERT INTO facts (tipe, date, fact, fulltext, who) values ('fact', date('now'), '$fact', '$fulltext', '$nick') ");
	$sth->execute();
	# (nick, seen, last) VALUES ('$nick', datetime('now'), '$msg')");
}

sub fffact {
	my $lfact = shift;
	my $sth = $dbh->prepare
	   ("SELECT fulltext from facts where fact='$lfact'");
	$sth->execute();
	my $row = $sth->fetchrow;
	if ($row) { 
		$row =~ s/^\ +//; 
		return $row 
	} else { return undef }

}


sub getkarma {
	my $nick = shift;
	my $sth = $dbh->prepare
	    ("SELECT karma from users where NICK='$nick'");
	$sth->execute();
	my $row = $sth->fetchrow;
	return $row;
}



#TODO fix this fucking karmacatch to deny that the same user gives karma to himself

sub karmacatch {
	my ($giver, $given) = @_;
	my @k = ("$giver", ($given =~ m/(\+\+|--)/));
	my $karma=0;
	if ($given !~ m/$giver/i) { 
		$given =~ s/(\+\+|--)//;
		push (@k, $given);
	} else { return }
	my $lucky = $given if ( &dbuexist($k[2]) );
	if ($lucky) {
	     my $sth = $dbh->prepare
	         ("SELECT karma from users where NICK='$lucky'");
	     $sth->execute();
	     my $row = $sth->fetchrow;
	     #if ($row[0] = 0) { $
	     if ($k[1] eq '++') {
		     $row++;
	     } else {
		     $row--;
	     }
             $dbh->do("UPDATE users SET karma='$row' WHERE nick='$lucky'");
	}

}

sub dbuexist {
	my $nick = shift;
	if ($nick) {
	    my $sth = $dbh->prepare
	        ("SELECT seen, last from users where NICK='$nick'");
	        $sth->execute();
	        my @row = $sth->fetchrow_array;
	        if ($row[0]) {
		#&say("en dbuexist: $row[0]", $nick, "no");
		    return @row;
	        } else { return undef }
	}
}

sub dblog {
	my ($nick, $msg) = @_;
	$msg =~ s/'//g;
	my @seen = &dbuexist($nick); 
	if ($seen[0]) {
		$dbh->do("UPDATE users SET seen=datetime('now'), last='$msg' WHERE nick='$nick'");
		#&say("UPDAE $nick, $msg", $nick, "no");
	} else {
		#FIXME bot never made any update on new users, or at least check if it is doing it
		my $sth = $dbh->prepare("INSERT INTO users (nick, seen, last) VALUES ('$nick', datetime('now'), '$msg')");
		$sth->execute();
		#&say("INSERT $nick, $msg", $nick, "no");
	}
}

sub definir {
#TODO this have some problems when the word has UTF-8 chars, like 'ratón'
	my $word = shift;
	my $wiki = WWW::Wikipedia->new();
	$wiki->language( 'es' );
	my $result = $wiki->search ($word) ;
	my $out; 
	if ($result) {
	   if ($result->text()){
		$out = $result->text();
	   } else { return }
	   $out =~ s/\n+/ /g;
	   $out =~ s/\{.+.\}|<!.+->//g;
	   $out =~ s/<ref>(.*?)<\/ref>//g;
	   $out =~ s/\[\[.+\]\]//gi;
	   $out =~ s/(.*?).\]\]//g;
	   $out = substr($out, 0, 199);
	   return "$out...";
	}
}
sub decifrar {
	my $search = shift;
	my $goo = Net::Google->new(key=>LOCAL_GOOGLE_KEY);
	my $word = $goo->spelling(phrase=>$search)->suggest();
	return $word;
}

sub google {
	my $search = shift;
	my $goo = Net::Google->new(key=>LOCAL_GOOGLE_KEY);
	my $goosh = $goo->search();
	$goosh->query($search);
	$goosh->lr(qw(es en));
	$goosh->max_results(1);

	my $answer;
	foreach (@{$goosh->results()}) {
		$answer = $_->URL();
	}
	return $answer;
}
sub fortune {
	my $fortune = `fortune  -a -n 160 -s`;
	return $fortune;
}

sub say {
	my ($msg, $nick, $usenick ) = @_;
	if ($usenick eq 'yes') {
		$irc->yield( privmsg => CHANNEL, "$nick: $msg");
	} else {
		$irc->yield( privmsg => CHANNEL, "$msg");
	}
	return
}

sub chanlog {
	my $logme = shift;
	open(LOG,">>$logfile") || die("This file will not open!");
	print LOG "$logme\n";
	close(LOG)
}


$poe_kernel->run();
exit 0;

