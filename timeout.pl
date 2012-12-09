#!/usr/bin/perl

# perl version of timeout
# I've found that timeout doesn't work quite right
# noninteractively, so I wrote this
# ps must be installed
#
# timeouts are in minutes
#
use strict;
use constant SECONDS_IN_MINUTE => 60;
use constant DEFAULT_SIGNAL => 9;

# returns a reference to a mapping of pids to parent pids
sub pidToParentPid() {
    my @output = `ps ax -o pid,ppid`;
    my %retval;

    foreach my $line ( @output ) {
	if ( $line =~ /(\d+)\s+(\d+)/ ) {
	    $retval{ $1 } = $2;
	}
    }

    return \%retval;
}

# returns a mapping of parent pids to direct children
# the direct children are references to arrays
sub parentPidToDirectChildren() {
    my $hashRef = pidToParentPid();
    my %retval;

    foreach my $childPid ( keys( %$hashRef ) ) {
	my $arrRef;
	if ( exists( $retval{ $hashRef->{ $childPid } } ) ) {
	    $arrRef = $retval{ $hashRef->{ $childPid } };
	} else {
	    my @arr;
	    $arrRef = \@arr;
	    $retval{ $hashRef->{ $childPid } } = $arrRef;
	}
	push( @$arrRef, $childPid );
    }

    return \%retval;
}

# Because Perl doesn't use inner functions properly...
# Takes:
# -pid
# -Mapping of pids to direct children
# returns an array of pids
sub recurChildProcesses( $$ );
sub recurChildProcesses( $$ ) {
    my ( $pid,
	 $directChildrenMap ) = @_;
    my @retval;
    my $childrenRef = $directChildrenMap->{ $pid };
    foreach my $child ( @$childrenRef ) {
	@retval = ( @retval, recurChildProcesses( $child, $directChildrenMap ) );
    }
    @retval = ( @retval, @$childrenRef );
    return @retval;
}

# given a pid, returns the pids of all child processes
# they are returned in order such that the deepest children are returned first
sub childProcesses( $ ) {
    my $pid = shift();
    my $hashRef = parentPidToDirectChildren();
    return recurChildProcesses( $pid, $hashRef );
}

# given  kill signal number and a pid, kills everything
# in the family, deepest children first
sub killFamily( $$ ) {
    my ( $signal, $pid ) = @_;
    kill $signal, childProcesses( $pid ), $pid;
}

my $duration = shift();
if ( $duration !~ /^\d+$/ ) {
    die "Duration must be an integer specifying the number of minutes to wait";
}

my $signal = DEFAULT_SIGNAL;
if ( $ARGV[ 0 ] eq '-signal' ) {
    shift( @ARGV ); # trim -signal
    $signal = shift( @ARGV );
    if ( $signal !~ /^\d+$/ ) {
	die "Signal must be an integer holding a UNIX signal number";
    }
}

my $majorPid = $$;
my $commandPid = fork();
if ( !defined( $commandPid ) ) {
    die "Failed to fork 1";
} elsif ( $commandPid == 0 ) {
    # process that executes the actual command
    my $command = join( " ",  @ARGV );
    exec( $command );
} else { #( $commandPid > 0 ) {
    my $watchPid = fork();
    if ( !defined( $watchPid ) ) {
	die "Failed to fork 2";
    } elsif ( $watchPid > 0 ) {
	waitpid( $commandPid, 0 );
	kill $signal, $watchPid;
    } else { # ( $watchPid == 0 ) {
	my $secondsWaited = 0;
	while ( $secondsWaited < $duration * SECONDS_IN_MINUTE ) {
	    $secondsWaited += sleep( SECONDS_IN_MINUTE );
	}

	killFamily( $signal, $commandPid );
    }
}
