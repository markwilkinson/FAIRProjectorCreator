#!perl -w

package junk;

use strict;
use CGI::Simple;
use LWP::Simple;
use FAIR::Accessor;
use FAIR::Accessor::Distribution;
use FAIR::Accessor::Container;
use FAIR::Accessor::MetaRecord;
use URI::Escape;

use base 'FAIR::Accessor';

 
my $DEBUG=0;

my $c = CGI::Simple->new();
my @params = $c->param();
$params[0]=1 if $DEBUG;
$c->param(-name => 'file', -value => 'http://some.file.org/thigng') if $DEBUG;


printHeader();



unless ($params[0]){
	print "<center><h2>FAIR Projector Builder</h2><br/>Please enter the URL of the tab-delimited file\n";
	print "<form method='GET'><input type='text' name='File'/><br/><input type='submit' value='Build FAIR Projector'/></form></center>";
	exit 1;
}

if ($c->param('predicateiri') || $DEBUG){
	
	my $config = {
		localNamespaces => {
			pfund => 'http://vocab.ox.ac.uk/projectfunding#term_',
			up => 'http://uniprot.org/ontology/core#', 
			},  # add a few new namespaces to the list of known namespaces....
		
	};
	
	my $Accessor = junk->new(%$config);
	my $ID = "ABCDEFG";

		
	do {
	    local *STDOUT;

	    # redirect STDOUT to log.txt
	    open (STDOUT, '>', '/tmp/accessor.txt');

		$Accessor->manageResourceGET(ID => $ID, NS => {});  # alls MetaRecord
	};

	open (IN, "</tmp/accessor.txt") || die "can't open infile $!\n";
	my @model = <IN>;
	my $model = join "\n", @model;
$model =~ m|(http://linkeddata.systems:30[^"]+)|;
my $location = $1;
	print "<h2>Your FAIR Projector is ready and running at:</h2><br/><a href='$location'>$location</a><br/><br/>";
	print "<h2>The FAIR Accessor including RML Mapping is:</h2><br/>";
	
	print "<pre>";
	
	use HTML::Escape qw/escape_html/;
     print escape_html($model);

	print "<pre/><br/><br/>";
	
	print "<h2>The auto-generated Plack server configuration file is:</h2><br/><br/>";
	my $plack = getPlackConfig();

	print "<pre>";
	
	use HTML::Escape qw/escape_html/;
     print escape_html($plack);

	print "<pre/><br/><br/>";

	
} else {
	my $file = $c->param('File');
	my $content = get($file);
	#print "File: $file\n";
	
	my @lines = split "\n", $content;
	my $a = $lines[0];
	my @matches = $a =~ /\t/g;
	print "<br/><br/>columns: ", scalar(@matches)+1, "\n";
	
	print "<pre>";
	
	foreach my $b (1..scalar(@matches)+1){
		print "Column $b\t";
	}
	print "\n\n";
	foreach my $a (0..3){
			print $lines[$a], "\n";
	}
	print "</pre><br/><br/><br/><br/>";
	
	print "<form><br/><center>";
	print"<input type='text' name='File' value='$file'/><br/><br/>";
	print "Number of Header Lines: <input type='text' width='1' size='1' name='headers'/><br/><br/>\n";
	print "Column # you want to FAIR Project as Subject: <input type='text' width='2' size='2' name='column1'/><br/><br/>\n";
	print "Column # you want to FAIR Project as Object: <input type='text' width='2' size='2' name='column2'/><br/><br/>\n";
	
	
	printOLSFields();
	
	print "</center>";
}
exit 1;


sub MetaRecord {
	my ($self, %ARGS) = @_;
	
	my $sub = $c->param('subjectiri');
	my $pred = $c->param('predicateiri');
	my $obj = $c->param('objectiri');
	my $sstruct = $c->param('subjectstructure');
	my $ostruct = $c->param('objectstructure');
	my $headers = $c->param('headers');
	my $col1 = $c->param('column1');
	my $col2 = $c->param('column2');
	my $file = $c->param('File');

	my $ID = $ARGS{'ID'};

	my $MetaRecord = FAIR::Accessor::MetaRecord->new(ID => $ID,
                                                    NS => $self->Configuration->Namespaces);
	$self->fillMetadata($MetaRecord);
	
	$MetaRecord->addDistribution(availableformats => ['text/csv'],
						    downloadURL => $file);
	
	
	my $encodedpredicate = urlencode($pred);
	my $TPF = "http://linkeddata.systems:3002/fragments?predicate=$encodedpredicate";  
	$MetaRecord->addDistribution(
		 availableformats => ["application/x-turtle", "application/rdf+xml", "text/html"],
		 downloadURL => $TPF,
		 source => $file,
		 subjecttemplate =>  $sstruct,
		 subjecttype => $sub,
		 predicate => $pred,
		 objecttemplate => $ostruct,
		 objecttype => $obj,      
	);
	
	return $MetaRecord	

}


sub printHeader {
print "Content-type: text/html\n\n";
	print <<'EOF';
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <title> This is an example of the ontology autocomplete widget</title>

<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"></script>
 <script src="https://cdnjs.cloudflare.com/ajax/libs/handlebars.js/4.0.5/handlebars.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/corejs-typeahead/0.11.1/typeahead.bundle.min.js"></script>
<script src="../js/ols-autocomplete.js"></script>

<link rel="stylesheet" href="../css/ols-colors.css" type="text/css" />
<link rel="stylesheet" href="../css/ols.css" type="text/css" />
<link rel="stylesheet" href="../css/bootstrap.css" type="text/css" />
<link rel="stylesheet" href="../css/typeaheadjs.css" type="text/css"/>


</head>
<body>


<script>
$(document).ready(function() {
  var app = require("ols-autocomplete");
  var instance = new app();
  instance.start({});
});
</script>

EOF

}

sub printOLSFields {
	
	print <<'EOF';

<h2>OLS autocomplete widget</h2>
<div class="grid_10 omega" style="margin-left:30px">
			 
      <h3>Subject</h3>
			 
                  URI Structure: <input type="text" name = "subjectstructure" id="subjectstructure" value="http://example.org/ids/{}"/><br/>
			 
                  <input type="hidden" name = "subjectiri" id="subjecttype" value=""/>
                        <label>
                            <input style="font-weight: normal" size="35"
                                   type="text" name="subjecttype"
                                  data-olswidget="select"
                                   data-olsontology=""
                                   data-selectpath="http://www.ebi.ac.uk/ols/"
                                   olstype=""
                                   id="local-searchbox1"
                                   placeholder="Enter the term you are looking for"
                                   class="ac_input"/>
                        </label>

<br/><br/><br/>
      <h3>Predicate</h3>
			 
                  <input type="hidden" name = "predicateiri" id="predicatetype" value=""/>
                        <label>
                            <input style="font-weight: normal" size="35"
                                   type="text" name="predicatetype"
                                  data-olswidget="select"
                                   data-olsontology=""
                                   data-selectpath="http://www.ebi.ac.uk/ols/"
                                   olstype=""
                                   id="local-searchbox2"
                                   placeholder="Enter the term you are looking for"
                                   class="ac_input"/>
                        </label>
<br/><br/><br/>
      <h3>Object</h3>


                  URI Structure: <input type="text" name = "objectstructure" id="objectstructure" value="http://example.org/ids/{}"/><br/>
			 
                  <input type="hidden" name = "objectiri" id="objecttype" value=""/>
                        <label>
                            <input style="font-weight: normal" size="35"
                                   type="text" name="objecttype"
                                  data-olswidget="select"
                                   data-olsontology=""
                                   data-selectpath="http://www.ebi.ac.uk/ols/"
                                   olstype=""
                                   id="local-searchbox3"
                                   placeholder="Enter the term you are looking for"
                                   class="ac_input"/>
                        </label>
                        <div class="right">
<!--                            <input type="submit" value="Create My FAIR Projector!" class="submit"/> -->
                            <input type="submit" value="Create My FAIR Projector!"/>
                        </div>
				<br/>
				<br/><br/>
				</div>

                </form>

</body>
</html>
EOF

}


sub fillMetadata {
  my ($self, $MetaRecord) = @_;
  my $ID = $MetaRecord->ID;
  $MetaRecord->addMetadata({
      'foaf:primaryTopic' => "http://my.database.org/records/$ID",
      'dc:title' => "Record $ID",
      'dcat:identifier' => "http://my.database.org/records/$ID",
      'dcat:keyword' => ["Go", "FAIR"],
      'dc:creator' => 'Me',
      'dc:bibliographicCitation' => "Joe Bloggs (2016). How to write a FAIR Accessor, Online Journal 4:3.",
      'void:inDataset' => 'http://linkeddata.systems/cgi-bin/Accessors/UniProtAccessor/',
      'dc:license' => 'https://creativecommons.org/choose/zero',
        });
 
 return $MetaRecord;
}

sub urlencode {
    my $s = shift;
    $s =~ s/ /+/g;
    $s =~ s/([^A-Za-z0-9\+-])/sprintf("%%%02X", ord($1))/seg;
    return $s;
 }
 
 
 sub getPlackConfig {
	my ($self,) = @_;
	
	my $sub = $c->param('subjectiri');
	my $pred = $c->param('predicateiri');
	my $obj = $c->param('objectiri');
	my $sstruct = $c->param('subjectstructure');
	my $ostruct = $c->param('objectstructure');
	my $headers = $c->param('headers');
	my $col1 = $c->param('column1');
	my $col2 = $c->param('column2');
	my $file = $c->param('File');

	$sstruct =~ s/{}//;
	$ostruct =~ s/{}//;
	
	return qq[
	{
        "base_uri": "http://linkeddata.systems:3002",
        "store": {
                "storeclass": "RDF::Trine::Store::CSV_Store",
                "tarql": "/root/CODE/tarql-1.0a/bin/tarql",
                "file": "$file",
                "CONSTRUCT": \["PREFIX rdfs:<http://www.w3.org/2000/01/rdf-schema#> PREFIX up:<http://purl.uniprot.org/core/> ",
                        "CONSTRUCT {",
                        " ?url1 a <$sub> .",
                        " ?url1 <$pred> ?url2 .",
                        " ?url2 a <$obj> .",
                        "} ",
                        "WHERE { ",
                        "BIND(URI(CONCAT('$sstruct',?Entry)) as ?url1)  ",
                        "BIND(URI(CONCAT('$ostruct',?Entry_name)) as ?url2)  ",
                        " } ",
                \],
		   "csv": "someuniquecsv",
		   "tabs": "yes",
        },
        "endpoint": {
                "html": {
                        "resource_links": true
                }
        },
        "expires": "A86400",
        "cors": {
                "origins": "*"
        },
        "void": {
                "pagetitle": "FAIR Projector for a file"
        },
        "fragments": {
                "fragments_path": "/fragments"
        },
	}
	];
 }