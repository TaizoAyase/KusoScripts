#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::RealBin";

use XsUtil;

my $PERL = "perl";
my $RUNXDS="run_xds.pl";

$XsUtil::debug=1;

my %keys;
&read_input_file($ARGV[0], \%keys);

my $ndataset = int($keys{"NDATASET"});
my $cycle = $keys{"CYCLE"};
my $basedir = $keys{"BASEDIR"};

$XsUtil::use_qsub = $keys{"USE_QSUB"};

for (my $iset=1; $iset<=$ndataset; ++$iset) {
    &run_xds_mp($iset);
}

##########



sub run_xds_mp($)
{
    my $iset = shift;

    my @chkeys = ();
    my @values = ();
    my @lens = ();
    my @iter = ();

    iter_setup(\@chkeys, \@values, \@lens, \@iter, $iset, \%keys);

    my $prefix = getParam("PREFIX", $iset, \%keys);
    my $serial = 1;
    for (;;) {
	debug "Params: ", join(",",@chkeys), " (", join(",",@iter), ") = ", join(",", iter_getval(\@iter, \@values));

	my $cmd = "$PERL $RUNXDS $ARGV[0] $iset $serial";
	my $nam = sprintf("${prefix}_%02d", $serial);
	qsub_cmd($cmd, $nam);
	++$serial;

	last if (!iter_plus(\@iter, \@lens));
    }

}
