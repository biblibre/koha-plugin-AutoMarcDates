package Koha::Plugin::AutoMarcDates;

use Modern::Perl;

use POSIX qw(strftime);

use C4::Context;

use parent 'Koha::Plugins::Base';

sub new {
    my ($class, $args) = @_;

    $args->{metadata} = {
        name => 'AutoMarcDates',
        version => '0.1.0',
        author => 'BibLibre',
        minimum_version => undef,
        maximum_version => undef,
        description => 'Automatically set created/modified date in MARC (biblio and authority) upon creation/modification',
    };

    return $class->SUPER::new($args);
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    if ($cgi->request_method() eq 'POST') {
        $self->store_data({
            enable_biblio => $cgi->param('enable_biblio') // 0,
            enable_authority => $cgi->param('enable_authority') // 0,
            biblio_created_field => $cgi->param('biblio_created_field') // '',
            biblio_updated_field => $cgi->param('biblio_updated_field') // '',
            authority_created_field => $cgi->param('authority_created_field') // '',
            authority_updated_field => $cgi->param('authority_updated_field') // '',
        });
        $self->go_home();
        return;
    }

    my $template = $self->get_template({ file => 'configure.tt' });

    $template->param(
        enable_biblio => $self->retrieve_data('enable_biblio'),
        enable_authority => $self->retrieve_data('enable_authority'),
        biblio_created_field => $self->retrieve_data('biblio_created_field'),
        biblio_updated_field => $self->retrieve_data('biblio_updated_field'),
        authority_created_field => $self->retrieve_data('authority_created_field'),
        authority_updated_field => $self->retrieve_data('authority_updated_field'),
    );

    $self->output_html( $template->output() );
}

sub object_store_pre {
    my ($self, $object) = @_;

    my $type = $object->_type;
    if ($type eq 'BiblioMetadata' && $self->retrieve_data('enable_biblio')) {
        $self->_update_biblio_metadata($object);
    } elsif ($type eq 'AuthHeader' && $self->retrieve_data('enable_authority')) {
        $self->_update_auth_header($object);
    }
}

sub _update_biblio_metadata {
    my ($self, $biblio_metadata) = @_;

    my $record = $biblio_metadata->record;

    my $created_field = $self->retrieve_data('biblio_created_field');
    if ($created_field) {
        my $datecreated = $biblio_metadata->_result->biblionumber->datecreated;
        $self->_update_marc_record($record, $created_field, $datecreated);
    }

    my $updated_field = $self->retrieve_data('biblio_updated_field');
    if ($updated_field) {
        my $dateupdated = strftime('%Y-%m-%d', localtime);
        $self->_update_marc_record($record, $updated_field, $dateupdated, overwrite => 1);
    }

    $biblio_metadata->metadata($record->as_xml_record(C4::Context->preference('marcflavour')));
}

sub _update_auth_header {
    my ($self, $auth_header) = @_;

    return unless $auth_header->marcxml;

    my $flavour = C4::Context->preference('marcflavour') eq 'UNIMARC' ? 'UNIMARCAUTH' : 'MARC21';
    my $record = MARC::Record->new_from_xml($auth_header->marcxml, 'UTF-8', $flavour);

    my $created_field = $self->retrieve_data('authority_created_field');
    if ($created_field) {
        my $datecreated = $auth_header->datecreated;
        $self->_update_marc_record($record, $created_field, $datecreated);
    }

    my $updated_field = $self->retrieve_data('authority_updated_field');
    if ($updated_field) {
        my $dateupdated = strftime('%Y-%m-%d', localtime);
        $self->_update_marc_record($record, $updated_field, $dateupdated, overwrite => 1);
    }

    $auth_header->marcxml($record->as_xml_record($flavour));
}

sub _update_marc_record {
    my ($self, $record, $fieldspec, $value, %opts) = @_;

    if ($fieldspec && $fieldspec =~ /^(\d{3})\$([0-9a-zA-Z])$/) {
        my ($tag, $code) = ($1, $2);
        my $field = $record->field($tag);
        if ($field) {
            $field->update($code => $value) if $opts{overwrite} || !$field->subfield($code);
        } else {
            $field = MARC::Field->new($tag, ' ', ' ', $code => $value);
            $record->insert_grouped_field($field);
        }
    }
}

1;
