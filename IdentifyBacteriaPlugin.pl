#!/usr/bin/perl

# usage:
#   perl script.pl brenda_download.txt output.txt
#   perl script_identify_bacteria.pl brenda_download.txt bac_out_brenda_download.txt
#   perl script_identify_bacteria.pl brenda_download_shorter.txt bac_out_brenda_test.txt

use 5.010;
use strict;
use warnings;

use IO::File;
use WWW::Mechanize;
my $mech;

eval {
    require HTTP::Message;
    my $accepted_encodings = HTTP::Message::decodable();
    $mech->default_header('Accept-Encoding' => $accepted_encodings);

    require LWP::ConnCache;
    my $cache = LWP::ConnCache->new;
    $cache->total_capacity(undef);    # no limit
    $mech->conn_cache($cache);
};

sub strip_space {
    my ($str) = @_;
    $str =~ s/^\s+//;
    unpack("A*", $str);
}

sub is_bacteria {
$mech = WWW::Mechanize->new(
           autocheck     => 0,
           timeout       => 60,
           env_proxy     => 1,
           show_progress => 1,
           agent => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.121 Safari/537.36",
);
    my ($name) = @_;

    do {

        do {
            $mech->get("https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi");
        } until ($mech->response->is_success);

        $mech->submit_form(
                           form_number => 1,
                           fields      => {
                                      name   => $name,
                                      old_id => 0,
                                      lvl    => 0,
                                     }
                          );
    } until ($mech->response->is_success);

    my $content = $mech->response->decoded_content;

    # Check the Lineage to see it contains "Bacteria"
    if ($content =~ m{>Lineage</a>(.*?)</dd>}s) {
	
        my $lineage = $1;
        $lineage =~ s{<.*?>}{}gs;
        say "[*] Lineage is: $lineage";
        return ($lineage =~ /\bBacteria\b/);
    }

    warn "No lineage was found...\n";
    return 0;
}

sub process_file {
    my ($input_file, $output_file) = @_;

    open my $in_fh,  '<', $input_file  or die "Can't read from `$input_file`: $!";
    open my $out_fh, '>>', $output_file or die "Can't write to `$output_file`: $!";

    $out_fh->autoflush(1);
	my $enzyme_ID = "ID	1.1.1.1";
	my $foundEnzyme=0;
    while (defined(my $line = <$in_fh>)) {
		

		if ($line =~ /^\s*PR\s.*/ && $foundEnzyme ==1 && $line !~ /no activity/) {
			print "[*] Processing line: $line";
			my $name="";
			if ($line =~ /^\s*PR\s*#\s*[0-9]+\s*#\s*(.*?)<[^>]*>\s*\z/) {
				$name = strip_space($1);
			}elsif($line =~ /^\s*PR\s*#\s*[0-9]+\s*#\s*(.*?)\s*\z/) {
				$name = strip_space($1);
			} else{
				print "ERROR!";
			}

			$name =~ s{\(\s*#\s*\d+\s*#.*}{};   # remove anything after (#d*#
			$name =~ s/[A-Z0-9]{6,}.*//;        # remove anything after an ID, such as XXXXXX

			say "[*] Checking name <<$name>>";

			if (is_bacteria($name)) {
				say "[*] <<$name> is a bacteria.";
				$line =~ s/PR/BA/;    # replace PR with BA
			}

			print $out_fh $line;
		}
		else {
			my $chompLine=$line;
			chomp($chompLine);
			if($chompLine =~/ID\s.*/){
				print $line;
			}
			if($chompLine =~/$enzyme_ID.*/){
				$foundEnzyme=1;
				
			}
			if($foundEnzyme ==1){
				print $out_fh $line;
			}
		}
		
    }

    close $in_fh;
    close $out_fh;
}

my $brenda_file;
my $output_file;
sub input {
   $brenda_file = @_[0];
}

sub run {

}

sub output {
   $output_file = @_[0];
process_file($brenda_file, $output_file);
}

