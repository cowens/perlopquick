#!/usr/bin/perl
# vi: ts=4 sw=4 ht=4 :

use v5.12.0;
use strict;
use warnings;

{
	package GenHTML;

	use parent "Pod::Simple";
	use HTML::Entities;
	use Data::Dumper;

	my $in_link  = 0;
	my $in_head2 = 0;
	my @head2_id;
	my @head2_name;

	my %escapes = (
		" " => "-",
		'"' => "%22",
	);
	my $class = join "", keys %escapes;

	sub custom_escape {
		my $s = shift;
		$s =~ s/([$class])/$escapes{$1}/g;
		return $s;
	}

	sub _handle_element_start {
		my($parser, $element_name, $attr) = @_;

		given ($element_name) {
			print ""             when "Document";
			print "\t\t<h1>"     when "head1";
			print "\t\t<h3>"     when "head3";
			print "\t\t<pre>\n"  when "Verbatim";
			print "\t\t<p>\n"    when "Para";
			print "<code>"       when "C";
			print "<em>"         when "I";
			when ("head2") {
				$in_head2 = 1;
				print qq(\t\t<h2 id=")
			}
			when ("L") {
				my $base;
				my @to      = @{ref $attr->{to} ? $attr->{to} : []};
				my $doc     = join('', @to[2 .. $#to]);
				my @sec     = @{ref $attr->{section} ? $attr->{section} : []};
				my $section = join('',  @sec[2 .. $#sec]);
				
				if ($doc eq '"X"') {
					($section, $doc) = ($doc, $section);
				}

				if ($doc) {
					$base    = "http://perldoc.perl.org/$doc.html#";
					$in_link = $section ? 
						"<em>" . encode_entities($section) . "</em> in $doc" :
						$doc;
				} else {
					die "bad link: ", Dumper $attr unless $section;
					$base    = "#";
					$in_link = $section;
				}

				$section = custom_escape $section;
				print qq(<a href="$base$section">);
			}
			default {
				die "unhandled POD: $element_name";
			}
		}
	}

	sub _handle_element_end {
		my($parser, $element_name) = @_;
		given ($element_name) {
			print ""                 when "Document";
			print "</h1>\n"          when "head1";
			print "</h3>\n"          when "head3";
			print "\n\t\t</pre>\n"   when "Verbatim";
			print "\n\t\t</p>\n"     when "Para";
			print "</code>"          when "C";
			print "</em>"            when "I";
			when ("head2") {
				my $id   = join "", @head2_id;
				my $name = join "", @head2_name;
				@head2_id = @head2_name = ();
				print qq($id">$name</h2>\n);
				$in_head2 = 0;
			}
			when ("L") {
					$in_link = 0;
					print "</a>";
			}
			default {
				die "unhandled POD: $element_name";
			}
		}
	}

	sub _handle_text {
		my($parser, $text) = @_;

		unless ($in_link eq "0") {
				print $in_link;
				$in_link = "";
				return;
		}

		unless ($in_head2) {
			print encode_entities $text;
			return;
		}

		push @head2_name, $text;
		push @head2_id,   custom_escape $text;
	}
}

my $filename = shift;
my ($title) = $filename =~ m{([^/\\]+).pod};
print <<EOH;
<!doctype html>
<html>
	<head>
		<title>$title</title>
	</head>
	<body>
EOH
GenHTML->filter($filename);
print <<EOH;
	</body>
</html>
EOH
