package App::TimeTracker::Command::Category;
use strict;
use warnings;
use 5.010;

# ABSTRACT: use categories when tracking time with App::TimeTracker

our $VERSION = "1.000";

use Moose::Util::TypeConstraints;
use Moose::Role;

after '_load_attribs_start' => sub {
    my ( $class, $meta, $config ) = @_;

    my $cfg = $config->{category};
    return unless $cfg && $cfg->{categories};

    subtype 'ATT::Category'
        => as enum($cfg->{categories})
        => message {"$_ is not a valid category (as defined in the current config)"};

    $meta->add_attribute(
        'category' => {
            isa           => 'ATT::Category',
            is            => 'ro',
            required      => $cfg->{required},
            documentation => 'Category',
        } );
};

before [ 'cmd_start', 'cmd_continue', 'cmd_append' ] => sub {
    my $self = shift;

    $self->add_tag($self->category);
};

no Moose::Role;
1;

__END__

=head1 DESCRIPTION

Define some categories, which act like 'Super-Tags', for example:
"feature", "bug", "maint", ..

=head1 CONFIGURATION

=head2 plugins

Add C<Category> to the list of plugins.

=head2 category

add a hash named C<category>, containing the following keys:

=head3 required

Set to a true value if 'category' should be a required command line option

=head3 categories

A list (ARRAYREF) of category names.

=head1 NEW COMMANDS

none

=head1 CHANGES TO OTHER COMMANDS

=head2 start, continue, append

=head3 --category

    ~/perl/Your-Project$ tracker start --category feature

Make sure that 'feature' is a valid category and store it as a tag.

