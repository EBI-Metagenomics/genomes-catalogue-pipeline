#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Bio::Perl;
use File::Basename qw/basename/;
use File::Copy qw/mv cp/;
use File::Find qw/find/;

my %rank=(
  d => "domain",
  p => "phylum",
  c => "class",
  o => "order",
  f => "family",
  g => "genus",
  s => "species",
);

# Different logging functions to STDERR
sub logmsg   {print STDERR "@_";} # simple message
sub logmsgLn {logmsg "@_\n"; }    # newline
sub logmsgBg {logmsg "$0 @_"}     # with script name (BG: beginning of line)

exit main();

sub main{

  my $settings={};
  GetOptions($settings, qw(infile=s --sequence-dir=s --outputdir=s help)) or die $!;
  die usage() if($$settings{help});
  $$settings{infile} ||= die "ERROR: need --infile";
  $$settings{outputdir} ||= die "ERROR: need --outputdir";
  $$settings{'sequence-dir'}//="library";

  my $outputdir = $$settings{outputdir};

  if (!-d $outputdir){
    mkdir $outputdir;
  }

  mkdir "${outputdir}/taxonomy";
  mkdir $$settings{'sequence-dir'};
  mkdir $$settings{'sequence-dir'}."/gtdb";

  my $fastaIndex = fastaIndex($$settings{'sequence-dir'});
  logmsgBg "Loaded ".scalar(keys(%$fastaIndex))." fasta files into the index\n";

  while (my ($k,$v)=each %$fastaIndex){print "$k $v\n"}
  open(my $nodesFh, ">", "${outputdir}/taxonomy/nodes.dmp") or die "ERROR writing to nodes.dmp";
  open(my $namesFh, ">", "${outputdir}/taxonomy/names.dmp") or die "ERROR writing to names.dmp";

  my $rootTaxid=1;
  my %root=(
    taxid          => $rootTaxid,
    scientificName => "root",
    rank           => "root",
    parent         => $rootTaxid,
  );

  my $taxonCounter=1;
  my %taxon=(root=>\%root);

  print $nodesFh join("\t|\t", $root{taxid}, $root{parent}, $root{rank}, "", 0, 1, 11, 1, 0, 1, 1, 0)."\t|\n";
  print $namesFh join("\t|\t", $root{taxid}, $root{scientificName}, "", "scientific name")."\t|\n";

  open(my $inFh, "<", $$settings{infile}) or die "ERROR: could not read $$settings{infile}: $!";
  while(my $line=<$inFh>){
    next if($line=~/^\s*#/);
    chomp $line;
    my($asmid,$lineageStr)=split /\t/, $line;
    my $assemblyId = $asmid;

    $assemblyId=~s/^RS_//;   # remove prefix RS_
    $assemblyId=~s/^GB_//;   # remove prefix RS_
    $assemblyId=~s/\.\d+$//; # remove version

    logmsgBg "Loading ". $assemblyId.", ".substr($lineageStr,0,20)."...".substr($lineageStr,-40,40)."\n";
    my @lineage=split(/;/, $lineageStr);
    for(my $i=0;$i<@lineage;$i++){
      my $name = $lineage[$i];
      my ($rank,$scientificName) = split(/__/, $name);

      # If the taxon has not been defined yet, then write it up
      if(!defined($taxon{$name})){
        my $taxid = ++$taxonCounter;
        my $rank   = $rank{lc($rank)};

        my $parent;
        if($rank eq "domain"){
          $parent = $rootTaxid;
        } else {
          $parent = $taxon{$lineage[$i-1]}{taxid};
        }

        $taxon{$name} = {
          taxid          => $taxid,
          scientificName => $scientificName,
          rank           => $rank,
          parent         => $parent,
          asm            => $asmid,
        };

        print $nodesFh join("\t|\t", $taxid, $parent, $rank, "", 0, 1, 11, 1, 0, 1, 1, 0)."\t|\n";
        print $namesFh join("\t|\t", $taxid, $scientificName, "", "scientific name")."\t|\n";

      }
    }

    # Download the genome with the last taxid
    my $taxid = $taxon{$lineage[-1]}{taxid};
    my $filename = $$settings{'sequence-dir'}."/gtdb/$assemblyId.fna";
    my $before = $$settings{'sequence-dir'}."/$assemblyId.fa";

    print "Renaming $before $filename \n";

    cp($before, "$filename.tmp") or die $!;

    logmsgBg "  finding it ($assemblyId)...";
    
    print "Looking for file $filename\n";
    if(-e $filename && (stat($filename))[7] > 0){
      logmsgLn "file present, not downloading again.";
      print "Found file\n";
      next;
    }

    # Replace with taxids
    my $in=Bio::SeqIO->new(-file=>"$filename.tmp", -format=>"fasta");
    my $out=Bio::SeqIO->new(-file=>">$filename.kraken", -format=>"fasta");
    my %seenSeq=();
    while(my $seq=$in->next_seq){
      next if($seenSeq{$seq->seq}++); # avoid duplicate contigs within a genome
      my $id=$seq->id;
      $seq->desc(" "); # unset the description fields
      $seq->id("$id|kraken:taxid|$taxid");
      $out->write_seq($seq);
    }

    # Cleanup
    unlink("$filename.tmp"); # cleanup
    mv("$filename.kraken",$filename);
    logmsgLn "got it!\n";
  }

  close $inFh;
  logmsgLn;

  close $nodesFh;
  close $namesFh;

  return 0;
}

# Find all fasta files in a given directory
sub fastaIndex{
  my($dir,$settings)=@_;
  my %fasta;
  find({follow=>1, no_chdir=>1, wanted=>sub{
    return if(!-e $File::Find::name);
    return if($File::Find::name !~ /\.(fna|fasta|fa|fsa|fas)$/);
    # Transform the accession to simply the number.
    my $accession=basename($File::Find::name);
    # Remove any other extensions actually
    # TODO: modified
    # ---- $accession=~s/\..+$//; -> this was removing from: "SRR12456162_bin.2.fa" -> "SRR12456162_bin" and that doesn't
    # ---- match with the gtdb.txt file 
    $accession =~ s/\.(fna|fasta|fa|fsa|fas)$//;

    if($fasta{$accession}){
      die "ERROR: found accession $accession at least twice:\n  ".$File::Find::name."\n  $fasta{$accession}\n";
    }

    $fasta{$accession} = $File::Find::name;
  }},$dir);

  return \%fasta;
}

sub usage{
  "Usage: perl [--sequence-dir fasta] --infile gtdb.txt $0
  Where gtdb.txt is a two column file with assembly ID and semicolon-delimited lineage
  Outputs two folders for taxonomy and library of fasta files.

  --sequence-dir       (optional) Local directory from which to find fasta files.
                       Each fasta filename must match against the first column from
                       --infile.  Fasta files must be uncompressed.
                       Fasta file extensions can be: fna, fasta, fa, fsa, fas
  "
}

