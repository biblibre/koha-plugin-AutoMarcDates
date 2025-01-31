package Koha::Plugin::Com::BibLibre::AutoMarcDates;

use Modern::Perl;

use parent 'Koha::Plugins::Base';

use POSIX qw(strftime);
use MARC::Field;
use MARC::Record;
use C4::Context;

our $VERSION = '2.0';

our $metadata = {
    name        => 'AutoMarcDates',
    author      => 'BibLibre',
    description => 'Automatically set created/modified date in MARC (biblio and authority) upon creation/modification',
    date_authored   => '2021-04-21',
    date_updated    => '2025-01-31',
    minimum_version => '24.05',
    maximum_version => undef,
    version         => $VERSION,
};

sub new {
    my ($class, $args) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    return $self;
}

# Mandatory even if does nothing
sub install {
    my ( $self, $args ) = @_;
 
    return 1;
}
 
# Mandatory even if does nothing
sub upgrade {
    my ( $self, $args ) = @_;
 
    return 1;
}
 
# Mandatory even if does nothing
sub uninstall {
    my ( $self, $args ) = @_;
 
    return 1;
}

sub configure {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};
    my $op  = $cgi->param('op') // q{};

    if ( $op eq 'cud-save' ) {
        $self->store_data({
            enable_biblio => $cgi->param('enable_biblio') // 0,
            enable_authority => $cgi->param('enable_authority') // 0,
            biblio_created_field => $cgi->param('biblio_created_field') // '',
            biblio_created_override => $cgi->param('biblio_created_override') // 0,
            biblio_updated_field => $cgi->param('biblio_updated_field') // '',
            authority_created_field => $cgi->param('authority_created_field') // '',
            authority_created_override => $cgi->param('authority_created_override') // 0,
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
        biblio_created_override => $self->retrieve_data('biblio_created_override'),
        biblio_updated_field => $self->retrieve_data('biblio_updated_field'),
        authority_created_field => $self->retrieve_data('authority_created_field'),
        authority_created_override => $self->retrieve_data('authority_created_override'),
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

    my $flavour = C4::Context->preference('marcflavour');

    my $record;
    if ($biblio_metadata->can('record')) {
        $record = $biblio_metadata->record;
    } else {
        # For Koha < 19.05
        $record = MARC::Record->new_from_xml($biblio_metadata->metadata, 'utf8', $flavour);
    }

    my $created_field = $self->retrieve_data('biblio_created_field');
    my $created_override = $self->retrieve_data('biblio_created_override');
    if ($created_field) {
        my $datecreated = $biblio_metadata->_result->biblionumber->datecreated;
        $self->_update_marc_record($record, $created_field, $datecreated, override => $created_override);
    }

    my $updated_field = $self->retrieve_data('biblio_updated_field');
    if ($updated_field) {
        my $dateupdated = strftime('%Y-%m-%d', localtime);
        $self->_update_marc_record($record, $updated_field, $dateupdated, override => 1);
    }

    $biblio_metadata->metadata($record->as_xml_record($flavour));
}

sub _update_auth_header {
    my ($self, $auth_header) = @_;

    return unless $auth_header->marcxml;

    my $flavour = C4::Context->preference('marcflavour') eq 'UNIMARC' ? 'UNIMARCAUTH' : 'MARC21';
    my $record = MARC::Record->new_from_xml($auth_header->marcxml, 'UTF-8', $flavour);

    my $created_field = $self->retrieve_data('authority_created_field');
    my $created_override = $self->retrieve_data('authority_created_override');
    if ($created_field) {
        my $datecreated = $auth_header->datecreated;
        $self->_update_marc_record($record, $created_field, $datecreated, override => $created_override);
    }

    my $updated_field = $self->retrieve_data('authority_updated_field');
    if ($updated_field) {
        my $dateupdated = strftime('%Y-%m-%d', localtime);
        $self->_update_marc_record($record, $updated_field, $dateupdated, override => 1);
    }

    $auth_header->marcxml($record->as_xml_record($flavour));
}

sub _update_marc_record {
    my ($self, $record, $fieldspec, $value, %opts) = @_;

    my $override = $opts{override} // 0;

    if ($fieldspec && $fieldspec =~ /^(\d{3})\$([0-9a-zA-Z])$/) {
        my ($tag, $code) = ($1, $2);
        my $field = $record->field($tag);
        if ($field) {
            my $currvalue = $field->subfield($code);
            if ( !$currvalue || $override ) {
                $field->update( $code => $value );
            }
        } else {
            $field = MARC::Field->new($tag, ' ', ' ', $code => $value);
            $record->insert_grouped_field($field);
        }
    }
}

1;
