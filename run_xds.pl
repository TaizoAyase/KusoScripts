#!/usr/bin/perl

use strict;
use FindBin;
use lib "$FindBin::RealBin";
use XsUtil;

##########

my $XDS="xds_par";
my $XDS2MTZ="xds2mtz.py";

$XsUtil::debug=1;

my %keys;
&read_input_file($ARGV[0], \%keys);

my $ndataset = int($keys{"NDATASET"});
my $cycle = $keys{"CYCLE"};
my $basedir = $keys{"BASEDIR"};

my $active;
my $active2;
if ($ARGV[1]) {
    $active = int($ARGV[1]);
    print("Active1 set $active\n");
}

if ($ARGV[2]) {
    $active2 = int($ARGV[2]);
    $active2 = "" if ($active2<1);
    print("Active2 set $active2\n");
}

# run only the active set, if $active is set.
if ($active && $active>=1 && $active<=$ndataset) {
    print("Run for set $active\n");
    &run_xds_mp($active);
    exit(1);
}

# run all jobs, if $active is not set.
for (my $iset=1; $iset<=$ndataset; ++$iset) {
    &run_xds_mp($iset);
}

##########

sub get_sigbr($)
{
    my $lp = shift;
    open(IN, $lp) || die;

    my $rval = "";
    while (<IN>) {
	# chomp;
	if (/REFLECTING_RANGE=/) {
	    $rval .= $_;
	}
	if (/BEAM_DIVERGENCE=/) {
	    $rval .= $_;
	}
    }

    return $rval;
}

sub run_xds_mp($)
{
    my $iset = shift;

    my @chkeys = ();
    my @values = ();
    my @lens = ();
    my @iter = ();

    iter_setup(\@chkeys, \@values, \@lens, \@iter, $iset, \%keys);

    my $prefix = getParam("PREFIX", $iset, \%keys);

    # my @delphi_list = split(/[,\s]+/, getParam("DELPHI", $iset, \%keys));
    #debug("delphi=".join(", ", @delphi));

    my $serial = 1;
    for (;;) {
	my @params = iter_getval(\@iter, \@values);
	debug "Params: ", join(",",@chkeys), " (", join(",",@iter), ") = ", join(",", @params);

	if ($active2) {
	    if ($active2==$serial) {
		debug("Run only: $active2\n");
		run_xds_rcyc($prefix, $iset, $serial, \@chkeys, \@params);
		last;
	    }
	}
	else {
	    run_xds_rcyc($prefix, $iset, $serial, \@chkeys, \@params);
	}

	++$serial;

	last if (!iter_plus(\@iter, \@lens));
    }

}

sub run_xds_rcyc($$$$$)
{
    my ($prefix, $iset, $serial, $rchkeys, $rparams) = @_;

    my $workdir = sprintf("${prefix}_%02d", $serial);
    unless (-d $workdir) {
	mkdir($workdir);
    }
    
    my $sigbr = "";
    for (my $icyc=1; $icyc<=$cycle; ++$icyc) {
	run_xds($iset, $workdir, $icyc, $sigbr, $rchkeys, $rparams);
	
	if (-f "$workdir/INTEGRATE_$icyc.LP") {
	    $sigbr = get_sigbr("$workdir/INTEGRATE_$icyc.LP");
	}
	debug("sigbr: ", $sigbr);
	
	# run_cmd("(cd $workdir; $XDS2MTZ XDS_ASCII_$icyc.HKL)");
	# try_phxtest("$workdir/phx_$icyc", "../ccp4/XDS_ASCII_$icyc.mtz");
    }
}

sub run_xds_delphi($$$$)
{
    my ($prefix, $iset, $serial, $delphi) = @_;

    my $workdir = sprintf("${prefix}_%02d", $serial);
    unless (-d $workdir) {
	mkdir($workdir);
    }
    
    my $sigbr = "";
    for (my $icyc=1; $icyc<=$cycle; ++$icyc) {
	run_xds($iset, $workdir, $icyc, $sigbr, $delphi);
	
	if (-f "$workdir/INTEGRATE_$icyc.LP") {
	    $sigbr = get_sigbr("$workdir/INTEGRATE_$icyc.LP");
	}
	debug("sigbr: ", $sigbr);
	
	# run_cmd("(cd $workdir; $XDS2MTZ XDS_ASCII_$icyc.HKL)");
	# try_phxtest("$workdir/phx_$icyc", "../ccp4/XDS_ASCII_$icyc.mtz");
    }
}

sub run_xds($$$$$$)
{
    my $iset = shift;
    my $workdir = shift;
    my $icyc = shift;
    my $sigbr = shift;
    my $rchkeys = shift;
    my $rparams = shift;

    debug("iset: ",$iset);
    my $xds_tmpl = $keys{"XDS_TMPL"};
    #my $img_tmpl = $keys{"IMG_TMPL_$iset"};
    #my $img_range = $keys{"IMG_RANGE_$iset"};
    my $img_tmpl = getParam("IMG_TMPL", $iset, \%keys);
    my $img_range = getParam("IMG_RANGE", $iset, \%keys);

    $img_tmpl = absdir($img_tmpl, $basedir);

    debug("img tmpl: ",$img_tmpl);
    # debug("xds tmpl: ",$xds_tmpl);

    my $res_hi = getParam("RES_HI", $iset, \%keys);
    my $res_lo = getParam("RES_LO", $iset, \%keys);
    my $res_range = "$res_lo $res_hi";

    my $jobs;

    if ($icyc==1) {
	$jobs = "XYCORR INIT COLSPOT IDXREF DEFPIX INTEGRATE CORRECT";
    }
    else {
	$jobs = "INTEGRATE CORRECT";
	die unless (-f "$workdir/GXPARM.XDS");
	run_cmd("cp $workdir/GXPARM.XDS $workdir/XPARM.XDS");
    }
    
    # open(IN, $xds_tmpl) || die "$!";
    open(OUT, ">$workdir/XDS.INP") || die "$!";
    
    # my $line;
    #while($line = <IN> ){
    my @lines = split(/\n/, $xds_tmpl);
    foreach my $line (@lines) {
	debug $line;
	$line .= "\n";
	if ($line =~ /^JOB=/) {
	    $line = "JOB= $jobs\n";
	}
	
	# $line =~ s/\@DELPHI\@/$delphi/;
	$line =~ s/\@IMG_TMPL\@/$img_tmpl/;
	$line =~ s/\@IMG_RANGE\@/$img_range/;
	$line =~ s/\@RES_RANGE\@/$res_range/;
	
	print OUT "$line";
    }
    
    print OUT "$sigbr\n";
    print OUT "\n";
    print OUT "!!! change params !!!\n";

    # put the changing keywords
    for (my $i=0; $i<int(@$rchkeys); ++$i) {
	my $val = $rparams->[$i];
	$val =~ s/,/ /g;
	print OUT $rchkeys->[$i]."=".$val."\n";
    }
    print OUT "\n";

    #close(IN);
    close(OUT);
    
    my $log = sprintf("xds_%02d.log", $icyc);
    run_cmd("(cd $workdir; $XDS |tee $log)");

    mv_file("$workdir/XDS.INP", "$workdir/XDS_$icyc.INP");
    mv_file("$workdir/CORRECT.LP", "$workdir/CORRECT_$icyc.LP");
    mv_file("$workdir/XDS_ASCII.HKL", "$workdir/XDS_ASCII_$icyc.HKL");
    mv_file("$workdir/INTEGRATE.LP", "$workdir/INTEGRATE_$icyc.LP");
    mv_file("$workdir/INTEGRATE.HKL", "$workdir/INTEGRATE_$icyc.HKL");
}

