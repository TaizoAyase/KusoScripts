# Utility/Debug subroutines

package XsUtil;

use File::Basename;
use Exporter;

@ISA = qw(Exporter);

@EXPORT = qw(debug read_input_file run_cmd mv_file absdir qsub_cmd getParam searchKeys iter_zero iter_setup iter_plus iter_getval);

######################################################################

our $debug=1;
our $use_qsub=0;

sub debug
{
    return if (!$debug);

    print @_ ;
    print "\n";
}

sub read_input_file($$)
{
    my $fname = shift;
    my $rkeys = shift;

    open(IN, $fname) || die "$!: $fname";

    my $setid="";
    my $heredoc="";
    my $hdkey="";
    my $delim="";

    while (<IN>) {
	if ($hdkey) {
	    # heredoc mode
	    my $line = $_;
	    chomp $line;
	    if ($line eq $delim) {

		my $key = $hdkey;
		if ($setid) {
		    $key = $key."_".$setid;
		}
		debug "$key <= (long str...)";
		$rkeys->{$key} = $heredoc;
		
		$hdkey = "";
		$delim = "";
		$heredoc = "";
	    }
	    else {
		$heredoc .= $_;
	    }
	}
	else {
	    # normal mode
	    if (/^SET\s+(.*)/) {
		debug "Set ID=$1";
		$setid = $1;
	    }
	    elsif (/^RESET\s+(.*)/) {
		debug "Reset ID";
		$setid = "";
	    }
	    elsif (/^([\w\d]+)\s+<<(.*)/) {
		debug "heredoc $1 delim=$2";
		$hdkey = $1;
		$delim = $2;
		$heredoc="";
	    }
	    elsif (/^([\w\d]+)\s+(.*)/) {
		my $key = $1;
		if ($setid) {
		    $key = $key."_".$setid;
		}
		debug "$key <= $2";
		$rkeys->{$key} = $2;
	    }
	}
    }
    close(IN);
}

sub getParam($$$)
{
    my $key = shift;
    my $iset = shift;
    my $rkeys = shift;

    my $rval = $rkeys->{$key."_".$iset};
    unless ($rval) {
	unless ($iset==1) {
	    $rval = $rkeys->{$key."_1"};
	}
    }

    if ($rval) {
	$rval = sprintf($rval, $iset, $iset, $iset, $iset, $iset);
    }

    debug("getParam $key, $iset ==> $rval");
    return $rval;
}

sub searchKeysImpl($$$)
{
    my $prefix = shift;
    my $iset = shift;
    my $rkeys = shift;

    my $regex = "${prefix}_(.+)_${iset}";
    my @rval;
    foreach my $i (keys %$rkeys) {
	if ($i =~ /$regex/) {
	    push(@rval, $1);
	}
    }

    debug "searchKeys $prefix, $iset ==>", join(",",@rval);
    return @rval;
}

sub searchKeys($$$)
{
    my $prefix = shift;
    my $iset = shift;
    my $rkeys = shift;

    my @rval = searchKeysImpl($prefix, $iset, $rkeys);
    unless (@rval) {
	unless ($iset==1) {
	    @rval = searchKeysImpl($prefix, 1, $rkeys);
	}
    }

    return @rval;
}

sub run_cmd($)
{
    my $cmd = shift;
    debug($cmd);
    system($cmd);
}

sub mv_file($$)
{
    my $src = shift;
    my $dst = shift;
    run_cmd("mv $src $dst");
}

sub absdir($$)
{
    my $path = shift;
    my $base = shift;
    if ($path =~ /^\//) {
	return $path
    }
    return $base."/".$path;
}

sub qsub_cmd($$)
{
    my $cmd = shift;
    my $nam = shift;

    debug("qsub $use_qsub> ", $cmd);
    if ($use_qsub) {
	open(OUT, "|qsub -cwd -N $nam -j y -o $nam.log -S /bin/tcsh");
	print OUT "$cmd\n";
	close(OUT);
    }
    else {
	# system("$cmd >& $nam.log");
	system("$cmd");
    }
}

####

sub iter_zero($)
{
    my $riter = shift;
    my $sz = int(@{$riter});
    for (my $i=0; $i<$sz; ++$i) {
	$riter->[$i] = 0;
    }
}

sub iter_setup($$$$$$)
{
    my $rchkeys = shift;
    my $values = shift;
    my $lens = shift;
    my $iter = shift;
    my $iset = shift;
    my $rkeys = shift;

    foreach my $chk (searchKeys("K", $iset, $rkeys)) {
	debug "*** chg-key: ", $chk;
	my $s = getParam("K_".$chk, $iset, $rkeys);
	my @v = split(/\s+/, $s);
	debug "*** chg-values: ", join(",",@v);
	push(@$rchkeys, $chk);
	push(@$values, \@v);
	push(@$lens, int(@v));
	push(@$iter, 0);
    }
}

sub iter_plus($$)
{
    my $riter = shift;
    my $rlens = shift;

    my $sz = int(@{$riter});

    # debug "iter sz=$sz";
    for (my $i=0; $i<$sz; ++$i) {
	my $n = $riter->[$i];
	my $nmax = $rlens->[$i];
	++$n;
	if ($n<$nmax) {
	    $riter->[$i] = $n;
	    return 1;
	}
	else {
	    $riter->[$i] = 0;
	    next;
	}
    }
    return 0;
}

sub iter_getval($$)
{
    my $riter = shift;
    my $rvals = shift;

    my $sz = int(@{$riter});

    my @rval;
    # debug "iter sz=$sz";
    for (my $i=0; $i<$sz; ++$i) {
	my $v = $rvals->[$i]->[$riter->[$i]];
	push(@rval, $v);
    }

    return @rval;
}

1;
