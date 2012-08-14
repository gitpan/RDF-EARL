=head1 NAME

RDF::EARL - Generate W3C Evaluation and Report Language (EARL) test reports.

=head1 VERSION

This document describes RDF::EARL version 0.000_01.

=head1 SYNOPSIS

my $earl = RDF::EARL->new('http://thing-being-tested.com/');
$earl->pass('http://example.org/test1');
$earl->pass('http://example.org/test2');
$earl->fail('http://example.org/test3', 'failure explanation');
my $model = $earl->model;
# $model is a RDF::Trine::Model containing the test results in EARL format

=head1 DESCRIPTION

RDF::EARL allows generating test reports using the W3C
L<Evaluation and Report Language (EARL) 1.0 RDF vocabulary|http://www.w3.org/TR/EARL10-Schema/>.

Test reports are generated by defining a subject (the thing being tested), an
assertor (the thing doing the testing), and the result of a number of performed
tests. The result can be one of: passed, failed, can't tell, inapplicable, and untested
(see the methods below, or the EARL 1.0 documentation for more details).

Once the test results have been asserted, the EARL report data may be accessed
in a RDF::Trine::Model. This allows the testing system to augment the test data
with supplementary data such as links to or contact information for obtaining
more information about the subject, assertor, or testing setup.

Alternatively, the C<< as_string >> method will return the EARL report RDF data
as a string in the Turtle RDF format.

=head1 METHODS

=over 4

=cut

package RDF::EARL;

use strict;
use warnings;
use RDF::Trine qw(iri blank literal statement);
use RDF::Trine::Namespace qw(foaf rdf rdfs dc_terms xsd);
use Scalar::Util qw(blessed);

our ($VERSION);
BEGIN {
	$VERSION	= '0.000_01';
}

my $DOAP	= RDF::Trine::Namespace->new('http://usefulinc.com/ns/doap#');
my $EARL	= RDF::Trine::Namespace->new('http://www.w3.org/ns/earl#');

=item C<< new ( $subj_iri ) >>

=item C<< new ( subject => $subj_iri, assertor => $assertor_iri ) >>

Creates a new EARL testing object for asserting results of testing the thing
(code, project, etc.) represented by C<< $subj_iri >> by the testing code
represented by C<< $assertor_iri >>. If the C<< assertor >> key-value pair is
omitted, a default value for the RDF::EARL module will be used by default.

=cut

sub new {
	my $class	= shift;
	my %args;
	if (scalar(@_) == 1) {
		%args	= (subject => shift(@_));
	} else {
		%args	= @_;
	}
	my $subj	= $args{ subject } or die "RDF::EARL->new called without a subject IRI";
	my $vers	= $VERSION;
	$vers		=~ s/[.]/-/g;
	my $asrt	= $args{ assertor } || "http://purl.org/NET/cpan-uri/dist/RDF-EARL/v_${vers}";
	
	foreach ($subj, $asrt) {
		$_	= iri($_) unless blessed($_);
	}
	
	my $map		= RDF::Trine::NamespaceMap->new({
		rdf		=> $rdf,
		rdfs	=> $rdfs,
		dcterms	=> $dc_terms,
		earl	=> $EARL,
		
	});
	my $model	= RDF::Trine::Model->temporary_model;
	my $self	= bless({
		model	=> $model,
		subj	=> $subj,
		asrt	=> $asrt,
		map		=> $map,
	}, $class);
	return $self;
}

=item C<< assertor >>

Returns the RDF::Trine::Node::Resource object representing the thing doing the
testing. This is either the IRI passed to the constructor as C<<assertor>> or
a RDF::EARL IRI like L<http://purl.org/NET/cpan-uri/dist/RDF-EARL/v_0-001>.

=cut

sub assertor {
	my $self	= shift;
	return $self->{asrt};
}

=item C<< subject >>

Returns the RDF::Trine::Node::Resource object representing the thing being
tested. This is the IRI passed to the constructor as C<<subject>>.

=cut

sub subject {
	my $self	= shift;
	return $self->{subj};
}

=item C<< model >>

Returns the RDF::Trine::Model object containing the EARL result data.

=cut

sub model {
	my $self	= shift;
	return $self->{model};
}

sub _assert {
	my $self	= shift;
	my $test	= shift;
	my $result	= shift;
	my @comment	= @_;
	
	unless (blessed($test)) {
		$test	= iri($test);
	}
	my $model	= $self->model;
	my $a		= blank();
	my $r		= blank();
	$model->add_statement( statement($a, $rdf->type, $EARL->Assertion) );
	$model->add_statement( statement($a, $EARL->assertedBy, $self->assertor) );
	$model->add_statement( statement($a, $EARL->subject, $self->subject) );
	$model->add_statement( statement($a, $EARL->test, $test) );
	$model->add_statement( statement($a, $EARL->result, $r) );
	$model->add_statement( statement($r, $rdf->type, $EARL->TestResult) );
	$model->add_statement( statement($r, $EARL->outcome, $result) );
	foreach my $c (@comment) {
		my $l	= blessed($c) ? $c : literal($c);
		$model->add_statement( statement($r, $rdfs->comment, $l) );
	}
	return $a;
}

=item C<< pass ( $test, @comments ) >>

Asserts that the test identifed by the C<< $test >> IRI was passed by the subject
system. If there are any C<< @comments >> specified, they are asserted as
rdfs:comment statements on the respective earl:TestResult node in the result
model.
Returns the RDF::Trine::Node object corresponding to the just-made assertion.

=cut

sub pass {
	my $self	= shift;
	my $test	= shift;
	return $self->_assert($test, $EARL->passed, @_);
}

=item C<< fail ( $test, @comments ) >>

Asserts that the test identifed by the C<< $test >> IRI was failed by the subject
system. If there are any C<< @comments >> specified, they are asserted as
rdfs:comment statements on the respective earl:TestResult node in the result
model.
Returns the RDF::Trine::Node object corresponding to the just-made assertion.

=cut

sub fail {
	my $self	= shift;
	my $test	= shift;
	return $self->_assert($test, $EARL->failed, @_);
}

=item C<< cantTell ( $test, @comments ) >>

Asserts that it is unclear if the subject passed or failed the test identifed
by the C<< $test >> IRI. If there are any C<< @comments >> specified, they are
asserted as rdfs:comment statements on the respective earl:TestResult node in
the result model.
Returns the RDF::Trine::Node object corresponding to the just-made assertion.

=cut

sub cantTell {
	my $self	= shift;
	my $test	= shift;
	return $self->_assert($test, $EARL->cantTell, @_);
}

=item C<< inapplicable ( $test, @comments ) >>

Asserts that the test identifed by the C<< $test >> IRI is not applicable to the
subject system. If there are any C<< @comments >> specified, they are asserted as
rdfs:comment statements on the respective earl:TestResult node in the result
model.
Returns the RDF::Trine::Node object corresponding to the just-made assertion.

=cut

sub inapplicable {
	my $self	= shift;
	my $test	= shift;
	return $self->_assert($test, $EARL->inapplicable, @_);
}

=item C<< untested ( $test, @comments ) >>

Asserts that the test identifed by the C<< $test >> IRI was not tested by the
subject system. If there are any C<< @comments >> specified, they are asserted as
rdfs:comment statements on the respective earl:untested node in the result
model.
Returns the RDF::Trine::Node object corresponding to the just-made assertion.

=cut

sub untested {
	my $self	= shift;
	my $test	= shift;
	return $self->_assert($test, $EARL->untested, @_);
}

=item C<< as_string >>

Returns EARL report data as a string formatted as Turtle.

=cut

sub as_string {
	my $self	= shift;
	my $model	= $self->model;
	my $s		= RDF::Trine::Serializer->new('turtle', namespaces => $self->{map});
	return $s->serialize_model_to_string($model);
}

sub _debug {
	my $self	= shift;
	my $model	= $self->model;
	my $s		= RDF::Trine::Serializer->new('turtle', namespaces => $self->{map});
	$s->serialize_model_to_file(\*STDERR, $model);
}

=back

=head1 SEE ALSO

L<http://www.w3.org/TR/EARL10-Schema/>

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=head1 LICENSE

Copyright (c) 2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut