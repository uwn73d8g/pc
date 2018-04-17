#!/usr/bin/perl

use Getopt::Long;
use Data::Dumper;
use strict;

my $formatLength = {
    'B' => 1,
    'O' => 2,
    'R' => 2,
    'RI' => 3,
    'LI' => 3,
};

my $opHash = {
    'STOP' => [0, 'B', \&B],
    'NOP'  => [1, 'B', \&B],
    'LW'   => [2, 'R', \&R],
    'LB'   => [3, 'R', \&R],
    'SW'   => [4, 'R', \&R],
    'SB'   => [5, 'R', \&R],
    'ADD'  => [6, 'R', \&R],
    'SUB'  => [7, 'R', \&R],
    'MUL'  => [8, 'R', \&R],
    'DIV'  => [9, 'R', \&R],
    'ADDI' => [10, 'RI', \&RI],
    'AND'  => [11, 'R',\&R],
    'OR'   => [12, 'R',\&R],
    'XOR'  => [13, 'R',\&R],
    'SHFTL'=> [14, 'RI', \&RI],
    'SHFTR'=> [15, 'RI', \&RI],
    'CMP'  => [16, 'R',\&R],

    'BE'   => [17, 'O', \&O],
    'BLT'  => [18, 'O', \&O],
    'BGT'  => [19, 'O', \&O],
    'JR'   => [20, 'R', \&R],
    'CALL' => [21, 'LI', \&LI],
    'PRINTR' => [22, 'R', \&R],
    'PRINTM' => [23, 'R', \&R],
    'PRINTC' => [24, 'R', \&R],
};

# arg list indices for instruction fields
my $OP = 0;
my $IMMED_10 = 1;
my $RA = 1;
my $RB = 2;
my $RC = 3;
my $IMMED_12 = 3;
my $IMMED_15 = 2;

# symbol table.  Holds only labels.  Holds label -> address map.
my $symTable = {};

#------------------------------------------------
# usage
#------------------------------------------------
sub usage {
    my $msg = "
Usage: ./assembler.pl [OPTIONS] file.asm ...
       Assembles all source files into executable.
Options:
    --load  address   Specifies starting address (in hex) to load exe into memory.
                      Default: 0x0010
    --entry address   Address at which execution will start.  Label or hex.
                      Default: 0x0010
    --output name     Specify output file name.  '-' for stdout. 
                      Default: a.exe
    --version         Print version and halt
";
    die $msg;
}

#------------------------------------------------
# main
#------------------------------------------------

my $PC;
my $entryPoint;
my $outFilename = "a.exe";
my $wantVersion;

my $result = GetOptions ( "entry=s" => \$entryPoint,
			  "load=s" => \$PC,
                          "output=s" => \$outFilename,
                          "version" => \$wantVersion,);
if ( $wantVersion ) {
    print "Version: 1.1.0 (4/11/2018)\n";
    exit 0;
}
usage() unless $result && $ARGV[0];


# establish output file
unless ( $outFilename eq '-' ) {
    open(OUTFILE, ">$outFilename") || die "Couldn't open output file $outFilename";
    select OUTFILE;
}

# establish load point and entry point
if (defined($entryPoint) ) {
    $entryPoint = lc($entryPoint);
    die "Bad --entry option '$entryPoint'.  Must be in format 0Xabcd."
	unless $entryPoint =~ m/0x[0-9a-f]{4}$/;
    $entryPoint =~ s/^0x//;
}
else { $entryPoint = "0010"; }
$entryPoint = hex($entryPoint);
print sprintf("!%04x  # entry point is 0x%04x\n", $entryPoint, $entryPoint);

    
if ( defined($PC) ) {
    $PC = lc($PC);
    die "Bad --load option '$PC'.  Must be in format 0xabcd"
	unless $PC =~ m/^0[xX][0-9a-f]{4}$/;
}
else { $PC = "0010"; }
$PC = hex($PC);
print sprintf("\@%04x\n", $PC);

#---------------------------------------------------------
# Assembler first pass
#  Process labels in all input files
#---------------------------------------------------------
my $inFilename;
my $lineNum;
my @inputLines = ();
while ( $inFilename = shift(@ARGV) ) {
    open(INFILE, "<$inFilename") || die "Couldn't open input file $inFilename";
    $lineNum = 0;

    while(<INFILE>) {
	$lineNum++;
	chomp;

	my $savedLine = $_;
	$_ = "$_ ";  # make sure there's whitespace terminating the line

	# remove comment, if any
	$_ =~ s/(#.*)//;

	# first token could be a label
	if ( s/^\s*([a-zA-Z_][a-zA-Z_0-9]*):\s+// ) {
	    my $label = $1;
	    $label = lc($label);  # canonicalize
	    die "At $inFilename:$lineNum: Multiply defined label '$label'"
		if  defined($symTable->{$label});
	    $symTable->{$label} = $PC;
	}

	# look for directives - .align and .data
	if (  m/^\s*\.align\s+/ ) {
	    my $entry = { PC => $PC,
			  type => 'align',
			  newPC => (($PC+1) & -2),
			  line => $savedLine,
			  lineNum => $lineNum,
			  filename => $inFilename,
	    };
	    push( @inputLines, $entry);
	    $PC = $entry->{newPC};
	    next;
	}
	
	if ( m/^\s*.data\s+/ ) {
	    m/^\s*.data\s+0[Xx]([0-9a-fA-F]+)\s*$/;
	    my $hexString = $1;
	    die "At $inFilename:$lineNum: invalid data"
		unless defined($hexString) && (length($hexString) % 2 == 0);
	    
	    my $entry = { PC => $PC,
			  type => 'data',
			  data => $hexString,
			  line => $savedLine,
			  lineNum => $lineNum,
			  filename => $inFilename,
	    };
	    push( @inputLines, $entry);
	    $PC += (length $hexString)/2;
	    next
	}
	
	# Should be an instruction
	# split line into tokens
	my @tokens = split;
	next unless @tokens;

	my $op = uc($tokens[$OP]);
	die "At $inFilename:$lineNum: Invalid op code: $tokens[$OP]"
	    unless defined($opHash->{$op});
	
	my $entry = { PC => $PC,
		      type => 'asm',
		      op => $op,
		      tokens => [@tokens],
		      line => $savedLine,
	              lineNum => $lineNum,
	              filename => $inFilename,
	};
	push( @inputLines, $entry);

	$PC += $formatLength->{$opHash->{$op}->[1]};
    }

    close(INFILE);
}

#-----------------------------------------------------------
# assembler second pass
#-----------------------------------------------------------

for my $entry (@inputLines) {
    $inFilename = $entry->{filename};
    $lineNum = $entry->{lineNum};

    $PC = $entry->{PC};

    my $inst;
    if ( $entry->{type} eq 'asm' ) {
	my $formatFunc = $opHash->{$entry->{op}}->[2];
	$inst = $formatFunc->(@{$entry->{tokens}});
	print "$inst\t# ", sprintf("%04x:", $PC), "  $entry->{line}\n";
    } elsif ( $entry->{type} eq 'data' )  {
	print "$entry->{data}\t# ", sprintf("%04x:", $PC), "  $entry->{line}\n";
    } elsif ( $entry->{type} eq 'align' ) {
	print "\t# ", sprintf("%04x:", $PC), "  $entry->{line}\n";
	if ( $entry->{newPC} != $PC ) {
	    print sprintf("\@%04x\n", $entry->{newPC});
	}
    }
    else { die "Internal error: bad 2nd pass entry type: '$entry->{type}'"; }
}

close(OUTFILE);


#------------------------------------------------
# Immediates must be specified as one of:
#    0xABC
#    $10
#    label
# An optional prefix, ':', means subact current PC
# from value.
#------------------------------------------------
sub processImmediate {
    my $immedString = shift;
    my $mask = shift;
    
    my $lcImmedString = lc($immedString);
    my $immedVal;

    my $reduction = 0;
    $reduction = $PC if $lcImmedString =~ s/^\://;

    if ( $lcImmedString =~ m/^0x([0-9a-f]+)$/ ) {
	$immedVal = hex($1) - $reduction;
    }
    elsif ( $lcImmedString =~ m/^\$(-?[0-9]+)$/ ) {
	$immedVal =  $1 - $reduction;
    }
    elsif ( defined($symTable->{$lcImmedString}) )  {
	$immedVal = $symTable->{$lcImmedString} - $reduction;
    }
    die "At $inFilename:$lineNum: Invalid immediate specifier: '$immedString'"
	unless defined($immedVal);

    my $maskedVal = $immedVal & $mask;
    print STDERR "At $inFilename:$lineNum: Warning - immediate value too large: $immedVal\n"
	unless $maskedVal == $immedVal;
    return $maskedVal;
}

#------------------------------------------------
# B format
#------------------------------------------------
sub B {
    my $op = shift;
    return sprintf("%02x", $opHash->{uc($op)}->[0] << 2);
}

#------------------------------------------------
# O format
#------------------------------------------------
sub O {
    my ($op, $immed_10) = @_;
    my $myImmed = processImmediate($immed_10, 0x3ff);
    return sprintf("%02x", ($opHash->{uc($op)}->[0] << 10) | $myImmed );
    
}

#------------------------------------------------
# R format
#------------------------------------------------
sub R {
    my ($op, $ra, $rb, $rc) = @_;
    $ra =~ s/^[Rr]//;
    $rb =~ s/^[Rr]//;
    $rc =~ s/^[Rr]//;
    return sprintf("%04x", ($opHash->{uc($op)}->[0] << 10) | 
		           (($ra & 7) << 7) | 
		           (($rb & 7) << 4) |
                           (($rc & 7) << 1));
}

#------------------------------------------------
# RI format
#------------------------------------------------
sub RI {
    my ($op, $ra, $rb, $immed_12) = @_;
    $ra =~ s/^[Rr]//;
    $rb =~ s/^[Rr]//;
    my $myImmed = processImmediate($immed_12, 0x0fff);
    return sprintf("%06x", ($opHash->{uc($op)}->[0] << 18) |
		           (($ra & 7) << 15) |
		           (($rb & 7) << 12) |
		           $myImmed);
}

#------------------------------------------------
# LI format
#------------------------------------------------
sub LI {
    my ($op, $ra, $immed_15) = @_;
    $ra =~ s/^[Rr]//;
    my $myImmed = processImmediate($immed_15, 0xffff) >> 1;
    
    return sprintf("%06x", ($opHash->{uc($op)}->[0] << 18) |
                           (($ra & 7) << 15) |
                           $myImmed);
}



